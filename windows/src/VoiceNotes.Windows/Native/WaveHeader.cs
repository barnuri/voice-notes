using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

[StructLayout(LayoutKind.Sequential)]
internal struct WaveHeader
{
    public nint Data;
    public uint BufferLength;
    public uint BytesRecorded;
    public nint User;
    public uint Flags;
    public uint Loops;
    public nint Next;
    public nint Reserved;
}
