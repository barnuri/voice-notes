namespace VoiceNotes.Core.Services;

public static class AudioLevel
{
    private const float SilenceFloor = 0.02f;
    private const float LevelGain = 4f;
    private const float FullScale = 32768f;

    public static float FromPcm16(ReadOnlySpan<byte> pcm)
    {
        var sampleCount = pcm.Length / sizeof(short);
        if (sampleCount == 0)
        {
            return 0;
        }
        double sumOfSquares = 0;
        for (var index = 0; index < sampleCount; index++)
        {
            var sample = BitConverter.ToInt16(pcm.Slice(index * sizeof(short), sizeof(short))) / FullScale;
            sumOfSquares += sample * sample;
        }
        var rms = (float)Math.Sqrt(sumOfSquares / sampleCount);
        return Math.Clamp((rms - SilenceFloor) * LevelGain, 0f, 1f);
    }
}
