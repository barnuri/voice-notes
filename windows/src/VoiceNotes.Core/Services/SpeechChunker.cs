namespace VoiceNotes.Core.Services;

public sealed class SpeechChunker
{
    public const float DefaultVoiceLevel = 0.03f;
    public static readonly TimeSpan DefaultMinChunk = TimeSpan.FromSeconds(5);
    public static readonly TimeSpan DefaultSilenceGap = TimeSpan.FromSeconds(0.7);
    public static readonly TimeSpan DefaultLongChunk = TimeSpan.FromSeconds(12);
    public static readonly TimeSpan DefaultWordGap = TimeSpan.FromSeconds(0.25);
    public static readonly TimeSpan DefaultMaxChunk = TimeSpan.FromSeconds(20);

    private DateTimeOffset chunkStartedAt;
    private DateTimeOffset? lastSpeechAt;

    public SpeechChunker(DateTimeOffset startedAt)
    {
        chunkStartedAt = startedAt;
    }

    public float VoiceLevel { get; init; } = DefaultVoiceLevel;

    public TimeSpan MinChunk { get; init; } = DefaultMinChunk;

    public TimeSpan SilenceGap { get; init; } = DefaultSilenceGap;

    public TimeSpan LongChunk { get; init; } = DefaultLongChunk;

    public TimeSpan WordGap { get; init; } = DefaultWordGap;

    public TimeSpan MaxChunk { get; init; } = DefaultMaxChunk;

    public bool HasSpeech { get; private set; }

    public void Reset(DateTimeOffset at)
    {
        chunkStartedAt = at;
        lastSpeechAt = null;
        HasSpeech = false;
    }

    public bool Observe(float level, DateTimeOffset at)
    {
        if (level >= VoiceLevel)
        {
            HasSpeech = true;
            lastSpeechAt = at;
        }
        var age = at - chunkStartedAt;
        if (age >= MaxChunk)
        {
            return true;
        }
        if (age < MinChunk || lastSpeechAt is not { } lastSpeech)
        {
            return false;
        }
        var quietFor = at - lastSpeech;
        return quietFor >= SilenceGap || (age >= LongChunk && quietFor >= WordGap);
    }
}
