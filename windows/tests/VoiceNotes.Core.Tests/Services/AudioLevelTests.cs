using System.Buffers.Binary;
using VoiceNotes.Core.Services;

namespace VoiceNotes.Core.Tests.Services;

public sealed class AudioLevelTests
{
    private static byte[] Pcm(params short[] samples)
    {
        var bytes = new byte[samples.Length * sizeof(short)];
        for (var index = 0; index < samples.Length; index++)
        {
            BinaryPrimitives.WriteInt16LittleEndian(bytes.AsSpan(index * sizeof(short)), samples[index]);
        }
        return bytes;
    }

    [Fact]
    public void EmptyBufferIsSilent()
    {
        Assert.Equal(0f, AudioLevel.FromPcm16([]));
    }

    [Fact]
    public void QuietNoiseUnderTheFloorIsSilent()
    {
        Assert.Equal(0f, AudioLevel.FromPcm16(Pcm(300, -300, 300, -300)));
    }

    [Fact]
    public void LoudSignalClampsToOne()
    {
        Assert.Equal(1f, AudioLevel.FromPcm16(Pcm(short.MaxValue, short.MinValue, short.MaxValue, short.MinValue)));
    }

    [Fact]
    public void MapsRmsWithWebFloorAndGain()
    {
        const short amplitude = 4096;
        var expected = (amplitude / 32768f - 0.02f) * 4f;
        Assert.Equal(expected, AudioLevel.FromPcm16(Pcm(amplitude, -amplitude, amplitude, -amplitude)), precision: 5);
    }

    [Fact]
    public void NormalSpeechReachesTheVoiceLevel()
    {
        const short amplitude = 1600;
        Assert.True(AudioLevel.FromPcm16(Pcm(amplitude, -amplitude)) >= SpeechChunker.DefaultVoiceLevel);
    }
}
