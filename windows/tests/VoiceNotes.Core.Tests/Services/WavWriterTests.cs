using System.Buffers.Binary;
using System.Text;
using VoiceNotes.Core.Services;

namespace VoiceNotes.Core.Tests.Services;

public sealed class WavWriterTests
{
    [Fact]
    public void WritesSixteenKilohertzMonoPcmHeaderWithFinalSizes()
    {
        var path = Path.Combine(Path.GetTempPath(), $"wav-test-{Guid.NewGuid()}.wav");
        try
        {
            using (var writer = new WavWriter(path))
            {
                writer.Write([1, 2, 3, 4]);
                writer.Write([5, 6]);
            }
            var bytes = File.ReadAllBytes(path);
            var span = bytes.AsSpan();
            Assert.Equal(WavWriter.HeaderSize + 6, bytes.Length);
            Assert.Equal("RIFF", Encoding.ASCII.GetString(bytes, 0, 4));
            Assert.Equal(36 + 6, BinaryPrimitives.ReadInt32LittleEndian(span[4..]));
            Assert.Equal("WAVEfmt ", Encoding.ASCII.GetString(bytes, 8, 8));
            Assert.Equal(16, BinaryPrimitives.ReadInt32LittleEndian(span[16..]));
            Assert.Equal(1, BinaryPrimitives.ReadInt16LittleEndian(span[20..]));
            Assert.Equal(1, BinaryPrimitives.ReadInt16LittleEndian(span[22..]));
            Assert.Equal(16_000, BinaryPrimitives.ReadInt32LittleEndian(span[24..]));
            Assert.Equal(32_000, BinaryPrimitives.ReadInt32LittleEndian(span[28..]));
            Assert.Equal(2, BinaryPrimitives.ReadInt16LittleEndian(span[32..]));
            Assert.Equal(16, BinaryPrimitives.ReadInt16LittleEndian(span[34..]));
            Assert.Equal("data", Encoding.ASCII.GetString(bytes, 36, 4));
            Assert.Equal(6, BinaryPrimitives.ReadInt32LittleEndian(span[40..]));
            Assert.Equal([1, 2, 3, 4, 5, 6], bytes[WavWriter.HeaderSize..]);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void WriteAfterDisposeThrows()
    {
        var path = Path.Combine(Path.GetTempPath(), $"wav-test-{Guid.NewGuid()}.wav");
        try
        {
            var writer = new WavWriter(path);
            writer.Dispose();
            writer.Dispose();
            Assert.Throws<ObjectDisposedException>(() => writer.Write([1, 2]));
        }
        finally
        {
            File.Delete(path);
        }
    }
}
