using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

[StructLayout(LayoutKind.Sequential)]
internal struct DataBlob
{
    public uint Length;
    public nint Data;
}
