using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Services;

public interface ITranscriber
{
    Task<string> TranscribeAsync(string audioPath, TranscriptionEndpoint endpoint, CancellationToken cancellationToken = default);
}
