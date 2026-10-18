namespace VoiceNotes.Core.Models;

public sealed class TranscriptionException : Exception
{
    public TranscriptionException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public static TranscriptionException NotConfigured() =>
        new("Add a server address and model in Settings.");

    public static TranscriptionException Unreachable(string host, Exception? cause = null) =>
        new($"VoiceNotes can't reach the transcription server at {host}. Check that the server is running.", cause);

    public static TranscriptionException TimedOut(string host, TimeSpan timeout, Exception? cause = null) =>
        new($"The transcription server at {host} didn't answer within {timeout.TotalSeconds:0} seconds.", cause);

    public static TranscriptionException Server(int status, string message) =>
        new($"The transcription server answered {status}: {message}");

    public static TranscriptionException UnreadableResponse() =>
        new("The transcription server sent a response that VoiceNotes can't read.");
}
