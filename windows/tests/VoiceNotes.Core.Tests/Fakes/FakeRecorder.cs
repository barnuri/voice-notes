using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;

namespace VoiceNotes.Core.Tests.Fakes;

public sealed class FakeRecorder : IAudioRecorder
{
    private readonly List<string> segments = [];
    private string? active;

    public bool FailStart { get; set; }

    public float Level { get; set; } = 0.8f;

    public IReadOnlyList<string> Segments => segments;

    public void Start()
    {
        if (FailStart)
        {
            throw new DictationException("No microphone.");
        }
        var path = Path.Combine(Path.GetTempPath(), $"fake-{Guid.NewGuid()}.wav");
        File.WriteAllText(path, "AUDIO");
        active = path;
    }

    public string Rotate()
    {
        var finished = Stop() ?? throw new InvalidOperationException("The fake recorder is not recording.");
        Start();
        return finished;
    }

    public string? Stop()
    {
        var finished = active;
        active = null;
        if (finished is not null)
        {
            segments.Add(finished);
        }
        return finished;
    }
}
