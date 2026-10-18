using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;

namespace VoiceNotes.Core.Tests.Fakes;

public sealed class FakeTranscriber(params Func<string>[] replies) : ITranscriber
{
    private readonly Queue<Func<string>> replies = new(replies);

    public int CallCount { get; private set; }

    public static Func<string> Says(string text) => () => text;

    public static Func<string> Fails(Exception error) => () => throw error;

    public Task<string> TranscribeAsync(string audioPath, TranscriptionEndpoint endpoint, CancellationToken cancellationToken = default)
    {
        CallCount++;
        var reply = replies.Count > 0 ? replies.Dequeue() : Says("");
        try
        {
            return Task.FromResult(reply());
        }
        catch (Exception error)
        {
            return Task.FromException<string>(error);
        }
    }
}
