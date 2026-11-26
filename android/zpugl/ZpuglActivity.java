package zpugl;

import android.app.NativeActivity;
import android.content.Context;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.text.Editable;
import android.text.InputType;
import android.text.Selection;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import java.nio.charset.StandardCharsets;

/**
 * NativeActivity with a text input connection for the zpugl Android backend. The soft keyboard edits the connection's
 * editable; every change reaches zpugl as backspaces plus new text, so composing text (か from k) shows up while typing.
 * The window draws edge to edge: the surface keeps its size, system bars, display cutout and soft keyboard reach zpugl as
 * insets in pixels.
 */
public class ZpuglActivity extends NativeActivity {
    private InputView input;
    private final int[] insets = new int[4];
    private boolean bound;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        input = new InputView(this);
        addContentView(input, new ViewGroup.LayoutParams(1, 1));
        Window window = getWindow();
        WindowManager.LayoutParams attrs = window.getAttributes();
        attrs.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        window.setAttributes(attrs);
        window.setStatusBarColor(Color.TRANSPARENT);
        window.setNavigationBarColor(Color.TRANSPARENT);
        View decor = window.getDecorView();
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false);
        } else {
            decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
        }
        decor.setOnApplyWindowInsetsListener(new View.OnApplyWindowInsetsListener() {
            @Override
            public WindowInsets onApplyWindowInsets(View v, WindowInsets in) {
                setInsets(in);
                return v.onApplyWindowInsets(in);
            }
        });
    }

    private void setInsets(WindowInsets in) {
        synchronized (insets) {
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets i = in.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout() | WindowInsets.Type.ime());
                insets[0] = i.left;
                insets[1] = i.top;
                insets[2] = i.right;
                insets[3] = i.bottom;
            } else {
                insets[0] = in.getSystemWindowInsetLeft();
                insets[1] = in.getSystemWindowInsetTop();
                insets[2] = in.getSystemWindowInsetRight();
                insets[3] = in.getSystemWindowInsetBottom();
            }
            if (bound) zpuglInsets(insets[0], insets[1], insets[2], insets[3]);
        }
    }

    /** Called by zpugl once its native methods are registered. */
    public void zpuglBind() {
        synchronized (insets) {
            bound = true;
            zpuglInsets(insets[0], insets[1], insets[2], insets[3]);
        }
    }

    /** Called by zpugl from its own thread. */
    public void zpuglTextInput(final boolean on) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
                if (on) {
                    input.setFocusable(true);
                    input.setFocusableInTouchMode(true);
                    input.requestFocus();
                    imm.restartInput(input);
                    imm.showSoftInput(input, 0);
                } else {
                    imm.hideSoftInputFromWindow(input.getWindowToken(), 0);
                }
            }
        });
    }

    static native void zpuglEdit(int backspaces, byte[] text);

    static native void zpuglInsets(int left, int top, int right, int bottom);

    static final class InputView extends View {
        InputView(Context context) {
            super(context);
        }

        @Override
        public boolean onCheckIsTextEditor() {
            return true;
        }

        @Override
        public InputConnection onCreateInputConnection(EditorInfo info) {
            info.inputType = InputType.TYPE_CLASS_TEXT;
            info.imeOptions = EditorInfo.IME_ACTION_NONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_FLAG_NO_FULLSCREEN;
            info.initialSelStart = 0;
            info.initialSelEnd = 0;
            return new Connection(this);
        }
    }

    static final class Connection extends BaseInputConnection {
        private String sent = "";

        Connection(View view) {
            super(view, true);
        }

        @Override
        public boolean commitText(CharSequence text, int newCursorPosition) {
            boolean done = super.commitText(text, newCursorPosition);
            sync();
            return done;
        }

        @Override
        public boolean setComposingText(CharSequence text, int newCursorPosition) {
            boolean done = super.setComposingText(text, newCursorPosition);
            sync();
            return done;
        }

        @Override
        public boolean deleteSurroundingText(int before, int after) {
            boolean done = super.deleteSurroundingText(before, after);
            sync();
            return done;
        }

        @Override
        public boolean deleteSurroundingTextInCodePoints(int before, int after) {
            boolean done = super.deleteSurroundingTextInCodePoints(before, after);
            sync();
            return done;
        }

        @Override
        public boolean sendKeyEvent(KeyEvent event) {
            int code = event.getKeyCode();
            if (code != KeyEvent.KEYCODE_DEL && code != KeyEvent.KEYCODE_ENTER) return super.sendKeyEvent(event);
            if (event.getAction() != KeyEvent.ACTION_DOWN) return true;
            if (code == KeyEvent.KEYCODE_ENTER) {
                zpuglEdit(0, new byte[] { '\n' });
                return true;
            }
            Editable editable = getEditable();
            int start = Selection.getSelectionStart(editable);
            int end = Selection.getSelectionEnd(editable);
            if (start != end) {
                editable.delete(Math.min(start, end), Math.max(start, end));
            } else if (start > 0) {
                boolean pair = start > 1 && Character.isSurrogatePair(editable.charAt(start - 2), editable.charAt(start - 1));
                editable.delete(start - (pair ? 2 : 1), start);
            } else {
                zpuglEdit(1, new byte[0]);
                return true;
            }
            sync();
            return true;
        }

        private void sync() {
            String text = getEditable().toString();
            int same = 0;
            int n = Math.min(text.length(), sent.length());
            while (same < n && text.charAt(same) == sent.charAt(same)) same++;
            if (same > 0 && Character.isHighSurrogate(text.charAt(same - 1))) same--;
            int backspaces = sent.codePointCount(same, sent.length());
            String added = text.substring(same);
            sent = text;
            if (backspaces > 0 || !added.isEmpty()) zpuglEdit(backspaces, added.getBytes(StandardCharsets.UTF_8));
        }
    }
}
