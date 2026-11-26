package zpugl;

import android.app.NativeActivity;
import android.content.Context;
import android.os.Bundle;
import android.text.Editable;
import android.text.InputType;
import android.text.Selection;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import java.nio.charset.StandardCharsets;

/**
 * NativeActivity with a text input connection for the zpugl Android backend. The soft keyboard edits the connection's
 * editable; every change reaches zpugl as backspaces plus new text, so composing text (か from k) shows up while typing.
 */
public class ZpuglActivity extends NativeActivity {
    private InputView input;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        input = new InputView(this);
        addContentView(input, new ViewGroup.LayoutParams(1, 1));
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
