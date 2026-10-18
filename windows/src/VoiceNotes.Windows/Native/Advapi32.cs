using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

internal static unsafe partial class Advapi32
{
    internal const uint TokenQuery = 0x0008;
    internal const int TokenElevationClass = 20;

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool OpenProcessToken(nint process, uint access, out nint token);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool GetTokenInformation(nint token, int informationClass, void* information, uint length, out uint returnLength);
}
