namespace VoiceNotes.Core.Models;

public sealed class DictationException : Exception
{
    public DictationException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public static DictationException RecordingNotSaved() =>
        new("The dictation recording didn't save. Try again.");
}
