using System.Runtime.InteropServices;

namespace VoiceNotes.Windows.Native;

internal static unsafe partial class WinMM
{
    internal const uint WaveMapper = uint.MaxValue;
    internal const uint CallbackEvent = 0x00050000;
    internal const uint HeaderDone = 0x00000001;
    internal const int NoError = 0;

    [LibraryImport("winmm.dll", EntryPoint = "waveInOpen")]
    internal static partial int WaveInOpen(out nint device, uint deviceId, WaveFormat* format, nint callback, nint instance, uint flags);

    [LibraryImport("winmm.dll", EntryPoint = "waveInPrepareHeader")]
    internal static partial int WaveInPrepareHeader(nint device, WaveHeader* header, uint headerSize);

    [LibraryImport("winmm.dll", EntryPoint = "waveInUnprepareHeader")]
    internal static partial int WaveInUnprepareHeader(nint device, WaveHeader* header, uint headerSize);

    [LibraryImport("winmm.dll", EntryPoint = "waveInAddBuffer")]
    internal static partial int WaveInAddBuffer(nint device, WaveHeader* header, uint headerSize);

    [LibraryImport("winmm.dll", EntryPoint = "waveInStart")]
    internal static partial int WaveInStart(nint device);

    [LibraryImport("winmm.dll", EntryPoint = "waveInReset")]
    internal static partial int WaveInReset(nint device);

    [LibraryImport("winmm.dll", EntryPoint = "waveInClose")]
    internal static partial int WaveInClose(nint device);
}
