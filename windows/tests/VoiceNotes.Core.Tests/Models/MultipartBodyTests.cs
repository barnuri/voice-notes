using System.Text;
using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Tests.Models;

public sealed class MultipartBodyTests
{
    [Fact]
    public void EncodesFieldsThenFileWithClosingBoundary()
    {
        var body = new MultipartBody("B");
        body.AddField("model", "whisper/x");
        body.AddFile("file", "a.wav", "audio/wav", "AUDIO"u8);
        var expected = "--B\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\nwhisper/x\r\n"
            + "--B\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\n"
            + "Content-Type: audio/wav\r\n\r\nAUDIO\r\n--B--\r\n";
        Assert.Equal(expected, Encoding.UTF8.GetString(body.ToArray()));
        Assert.Equal("multipart/form-data; boundary=B", body.ContentType);
    }

    [Fact]
    public void EncodesHebrewFieldValuesAsUtf8()
    {
        var body = new MultipartBody("B");
        body.AddField("prompt", "שלום");
        Assert.Contains("\r\n\r\nשלום\r\n", Encoding.UTF8.GetString(body.ToArray()), StringComparison.Ordinal);
    }

    [Fact]
    public void GeneratesUniqueBoundaryByDefault()
    {
        Assert.NotEqual(new MultipartBody().Boundary, new MultipartBody().Boundary);
    }
}
