using VoiceNotes.Core.Services;

namespace VoiceNotes.Core.Tests.Services;

public sealed class SpeechChunkerTests
{
    private const float Speech = 0.8f;
    private const float Silence = 0.01f;
    private static readonly DateTimeOffset Start = DateTimeOffset.FromUnixTimeSeconds(1_000);

    private static DateTimeOffset At(TimeSpan offset) => Start + offset;

    private static DateTimeOffset At(double seconds) => Start + TimeSpan.FromSeconds(seconds);

    [Fact]
    public void KeepsChunkOpenBeforeMinChunkEvenAfterSilence()
    {
        var chunker = new SpeechChunker(Start);
        Assert.False(chunker.Observe(Speech, At(0.5)));
        Assert.False(chunker.Observe(Silence, At(1.5)));
        Assert.False(chunker.Observe(Silence, At(SpeechChunker.DefaultMinChunk - TimeSpan.FromSeconds(0.1))));
    }

    [Fact]
    public void ClosesAfterSpeechThenSilenceGap()
    {
        var chunker = new SpeechChunker(Start);
        var minChunk = SpeechChunker.DefaultMinChunk;
        Assert.False(chunker.Observe(Speech, At(minChunk)));
        Assert.False(chunker.Observe(Silence, At(minChunk + TimeSpan.FromSeconds(0.5))));
        Assert.True(chunker.Observe(Silence, At(minChunk + TimeSpan.FromSeconds(0.75))));
        Assert.True(chunker.HasSpeech);
    }

    [Fact]
    public void PureSilenceStaysOpenUntilMaxChunk()
    {
        var chunker = new SpeechChunker(Start);
        for (var seconds = 0.0; seconds < SpeechChunker.DefaultMaxChunk.TotalSeconds; seconds += 0.5)
        {
            Assert.False(chunker.Observe(Silence, At(seconds)));
        }
        Assert.False(chunker.HasSpeech);
    }

    [Fact]
    public void ForcesCloseAtMaxChunkDuringContinuousSpeech()
    {
        var chunker = new SpeechChunker(Start);
        Assert.False(chunker.Observe(Speech, At(SpeechChunker.DefaultMaxChunk - TimeSpan.FromSeconds(0.1))));
        Assert.True(chunker.Observe(Speech, At(SpeechChunker.DefaultMaxChunk)));
    }

    [Fact]
    public void LongSpeechClosesAtBriefWordGapAfterLongChunk()
    {
        var chunker = new SpeechChunker(Start);
        var longChunk = SpeechChunker.DefaultLongChunk;
        Assert.False(chunker.Observe(Speech, At(longChunk)));
        Assert.False(chunker.Observe(Silence, At(longChunk + TimeSpan.FromSeconds(0.125))));
        Assert.True(chunker.Observe(Silence, At(longChunk + TimeSpan.FromSeconds(0.25))));
    }

    [Fact]
    public void BriefWordGapEarlyDoesNotClose()
    {
        var chunker = new SpeechChunker(Start);
        var minChunk = SpeechChunker.DefaultMinChunk;
        Assert.False(chunker.Observe(Speech, At(minChunk + TimeSpan.FromSeconds(0.5))));
        Assert.False(chunker.Observe(Silence, At(minChunk + TimeSpan.FromSeconds(0.75))));
    }

    [Fact]
    public void ResetStartsAFreshChunk()
    {
        var chunker = new SpeechChunker(Start);
        chunker.Observe(Speech, At(1));
        chunker.Reset(At(SpeechChunker.DefaultMaxChunk));
        Assert.False(chunker.HasSpeech);
        Assert.False(chunker.Observe(Silence, At(SpeechChunker.DefaultMaxChunk + TimeSpan.FromSeconds(2))));
    }

    [Fact]
    public void LevelBelowVoiceLevelIsNotSpeech()
    {
        var chunker = new SpeechChunker(Start);
        chunker.Observe(SpeechChunker.DefaultVoiceLevel - 0.001f, At(1));
        Assert.False(chunker.HasSpeech);
        chunker.Observe(SpeechChunker.DefaultVoiceLevel, At(2));
        Assert.True(chunker.HasSpeech);
    }
}
