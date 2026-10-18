using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

[StructLayout(LayoutKind.Sequential, Pack = 1)]
internal struct WaveFormat
{
    public ushort FormatTag;
    public ushort Channels;
    public uint SamplesPerSecond;
    public uint AverageBytesPerSecond;
    public ushort BlockAlign;
    public ushort BitsPerSample;
    public ushort ExtraSize;
}
