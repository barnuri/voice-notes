using System.Media;
using VoiceNotes.Core.Models;

namespace VoiceNotes.Windows.Services;

internal static class DictationSounds
{
    internal static void Play(DictationPhase phase)
    {
        switch (phase)
        {
            case DictationPhase.Listening:
                SystemSounds.Asterisk.Play();
                break;
            case DictationPhase.Transcribing:
                SystemSounds.Beep.Play();
                break;
            default:
                break;
        }
    }

    internal static void PlayError() => SystemSounds.Hand.Play();
}
