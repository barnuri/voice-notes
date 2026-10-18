namespace VoiceNotes.Core.Services;

public interface IAudioRecorder
{
    float Level { get; }

    void Start();

    string Rotate();

    string? Stop();
}
