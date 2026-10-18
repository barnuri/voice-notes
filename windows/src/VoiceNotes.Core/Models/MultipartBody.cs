using System.Buffers;
using System.Text;

namespace VoiceNotes.Core.Models;

public sealed class MultipartBody
{
    private const string LineBreak = "\r\n";
    private readonly ArrayBufferWriter<byte> buffer = new();

    public MultipartBody(string? boundary = null)
    {
        Boundary = boundary ?? $"VoiceNotes-{Guid.NewGuid()}";
    }

    public string Boundary { get; }

    public string ContentType => $"multipart/form-data; boundary={Boundary}";

    public void AddField(string name, string value)
    {
        AppendLine($"--{Boundary}");
        AppendLine($"Content-Disposition: form-data; name=\"{name}\"");
        AppendLine("");
        AppendLine(value);
    }

    public void AddFile(string name, string fileName, string mimeType, ReadOnlySpan<byte> contents)
    {
        AppendLine($"--{Boundary}");
        AppendLine($"Content-Disposition: form-data; name=\"{name}\"; filename=\"{fileName}\"");
        AppendLine($"Content-Type: {mimeType}");
        AppendLine("");
        buffer.Write(contents);
        AppendLine("");
    }

    public byte[] ToArray()
    {
        var closing = Encoding.UTF8.GetBytes($"--{Boundary}--{LineBreak}");
        return [.. buffer.WrittenSpan, .. closing];
    }

    private void AppendLine(string line) => buffer.Write(Encoding.UTF8.GetBytes(line + LineBreak));
}
