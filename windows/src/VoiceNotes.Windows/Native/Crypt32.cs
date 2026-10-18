using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

internal static unsafe partial class Crypt32
{
    internal const uint ProtectUiForbidden = 0x1;

    [LibraryImport("crypt32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool CryptProtectData(
        DataBlob* dataIn,
        nint description,
        DataBlob* entropy,
        nint reserved,
        nint prompt,
        uint flags,
        DataBlob* dataOut);

    [LibraryImport("crypt32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool CryptUnprotectData(
        DataBlob* dataIn,
        nint description,
        DataBlob* entropy,
        nint reserved,
        nint prompt,
        uint flags,
        DataBlob* dataOut);
}
