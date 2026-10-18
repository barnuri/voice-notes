export async function copyText(text, fallbackField) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    if (!fallbackField) {
      return false;
    }
    const { selectionStart, selectionEnd } = fallbackField;
    fallbackField.select();
    const copied = document.execCommand('copy');
    fallbackField.setSelectionRange(selectionStart, selectionEnd);
    return copied;
  }
}
