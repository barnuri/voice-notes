using VoiceNotes.Core.Services;

namespace VoiceNotes.Core.Tests.Fakes;

public sealed class FakeTyper : ITextTyper
{
    private readonly List<string> typed = [];

    public Exception? Failure { get; set; }

    public IReadOnlyList<string> Typed => typed;

    public void Type(string text)
    {
        if (Failure is not null)
        {
            throw Failure;
        }
        typed.Add(text);
    }
}
