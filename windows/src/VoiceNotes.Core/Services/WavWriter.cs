using System.Buffers.Binary;
using System.Text;

namespace VoiceNotes.Core.Services;

public sealed class WavWriter : IDisposable
{
    public const int SampleRate = 16_000;
    public const short Channels = 1;
    public const short BitsPerSample = 16;
    public const int HeaderSize = 44;
    public const short BlockAlign = Channels * BitsPerSample / 8;
    public const int ByteRate = SampleRate * BlockAlign;

    private const int FormatChunkSize = 16;
    private const short PcmFormat = 1;
    private const int RiffSizeOffset = 4;
    private const int DataSizeOffset = 40;
    private const int RiffHeaderOverhead = HeaderSize - 8;

    private readonly FileStream stream;
    private int dataLength;
    private bool disposed;

    public WavWriter(string path)
    {
        Path = path;
        stream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.Read);
        stream.Write(BuildHeader(dataLength: 0));
    }

    public string Path { get; }

    public static byte[] BuildHeader(int dataLength)
    {
        var header = new byte[HeaderSize];
        var span = header.AsSpan();
        Encoding.ASCII.GetBytes("RIFF").CopyTo(span);
        BinaryPrimitives.WriteInt32LittleEndian(span[RiffSizeOffset..], RiffHeaderOverhead + dataLength);
        Encoding.ASCII.GetBytes("WAVEfmt ").CopyTo(span[8..]);
        BinaryPrimitives.WriteInt32LittleEndian(span[16..], FormatChunkSize);
        BinaryPrimitives.WriteInt16LittleEndian(span[20..], PcmFormat);
        BinaryPrimitives.WriteInt16LittleEndian(span[22..], Channels);
        BinaryPrimitives.WriteInt32LittleEndian(span[24..], SampleRate);
        BinaryPrimitives.WriteInt32LittleEndian(span[28..], ByteRate);
        BinaryPrimitives.WriteInt16LittleEndian(span[32..], BlockAlign);
        BinaryPrimitives.WriteInt16LittleEndian(span[34..], BitsPerSample);
        Encoding.ASCII.GetBytes("data").CopyTo(span[36..]);
        BinaryPrimitives.WriteInt32LittleEndian(span[DataSizeOffset..], dataLength);
        return header;
    }

    public void Write(ReadOnlySpan<byte> pcm)
    {
        ObjectDisposedException.ThrowIf(disposed, this);
        stream.Write(pcm);
        dataLength += pcm.Length;
    }

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }
        disposed = true;
        stream.Position = 0;
        stream.Write(BuildHeader(dataLength));
        stream.Dispose();
    }
}
