using System.Net;
using System.Text;
using VoiceNotes.Core.Models;
using VoiceNotes.Core.Services;
using VoiceNotes.Core.Tests.Fakes;

namespace VoiceNotes.Core.Tests.Services;

public sealed class TranscriptionClientTests : IDisposable
{
    private readonly string audioPath = Path.Combine(Path.GetTempPath(), $"vn-{Guid.NewGuid()}.wav");

    public TranscriptionClientTests()
    {
        File.WriteAllText(audioPath, "AUDIO");
    }

    public void Dispose() => File.Delete(audioPath);

    private static TranscriptionEndpoint Endpoint(string apiKey = "", TranscriptionLanguage? language = null) =>
        TranscriptionEndpoint.Create("https://h/v1", "whisper/x", apiKey, language ?? TranscriptionLanguage.HebrewWithEnglish)!;

    private static HttpResponseMessage Reply(HttpStatusCode status, string body) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    private static (TranscriptionClient Client, StubHttpHandler Handler) ClientReplying(HttpStatusCode status, string body)
    {
        var handler = new StubHttpHandler(_ => Reply(status, body));
        return (new TranscriptionClient(new HttpClient(handler)), handler);
    }

    [Fact]
    public async Task PostsMultipartWithFieldsInOrderAndReturnsTrimmedText()
    {
        var (client, handler) = ClientReplying(HttpStatusCode.OK, """{"text":" שלום there\n"}""");
        var text = await client.TranscribeAsync(audioPath, Endpoint());

        Assert.Equal("שלום there", text);
        var request = Assert.IsType<HttpRequestMessage>(handler.LastRequest);
        Assert.Equal(HttpMethod.Post, request.Method);
        Assert.Equal("https://h/v1/audio/transcriptions", request.RequestUri!.AbsoluteUri);
        Assert.Null(request.Headers.Authorization);
        Assert.StartsWith("multipart/form-data; boundary=", request.Content!.Headers.ContentType!.ToString(), StringComparison.Ordinal);
        var body = handler.LastBody!;
        var model = body.IndexOf("name=\"model\"\r\n\r\nwhisper/x\r\n", StringComparison.Ordinal);
        var language = body.IndexOf("name=\"language\"\r\n\r\nhe\r\n", StringComparison.Ordinal);
        var prompt = body.IndexOf("name=\"prompt\"", StringComparison.Ordinal);
        var file = body.IndexOf($"name=\"file\"; filename=\"{Path.GetFileName(audioPath)}\"\r\nContent-Type: audio/wav\r\n\r\nAUDIO\r\n", StringComparison.Ordinal);
        Assert.True(model >= 0 && language > model && prompt > language && file > prompt, body);
    }

    [Theory]
    [InlineData("english", "en")]
    [InlineData("auto", "auto")]
    public async Task OmitsPromptForLanguagesWithoutOne(string languageId, string code)
    {
        var (client, handler) = ClientReplying(HttpStatusCode.OK, """{"text":"hi"}""");
        await client.TranscribeAsync(audioPath, Endpoint(language: TranscriptionLanguage.FromId(languageId)));
        Assert.DoesNotContain("name=\"prompt\"", handler.LastBody, StringComparison.Ordinal);
        Assert.Contains($"name=\"language\"\r\n\r\n{code}\r\n", handler.LastBody, StringComparison.Ordinal);
    }

    [Fact]
    public async Task SendsBearerOnlyWithApiKey()
    {
        var (client, handler) = ClientReplying(HttpStatusCode.OK, """{"text":"hi"}""");
        await client.TranscribeAsync(audioPath, Endpoint(apiKey: "k"));
        Assert.Equal("Bearer k", handler.LastRequest!.Headers.Authorization!.ToString());
    }

    [Theory]
    [InlineData("""{"error":{"message":"all attempts failed"}}""", "all attempts failed")]
    [InlineData("""{"error":"FFmpeg conversion failed."}""", "FFmpeg conversion failed.")]
    [InlineData("plain", "plain")]
    public async Task ServerErrorCarriesStatusAndMessage(string body, string message)
    {
        var (client, _) = ClientReplying(HttpStatusCode.BadGateway, body);
        var error = await Assert.ThrowsAsync<TranscriptionException>(() => client.TranscribeAsync(audioPath, Endpoint()));
        Assert.Equal($"The transcription server answered 502: {message}", error.Message);
    }

    [Theory]
    [InlineData("nope")]
    [InlineData("""{"result":"hi"}""")]
    [InlineData("""["hi"]""")]
    public async Task UnreadableSuccessBodyThrows(string body)
    {
        var (client, _) = ClientReplying(HttpStatusCode.OK, body);
        var error = await Assert.ThrowsAsync<TranscriptionException>(() => client.TranscribeAsync(audioPath, Endpoint()));
        Assert.Equal(TranscriptionException.UnreadableResponse().Message, error.Message);
    }

    [Fact]
    public async Task ConnectionFailureReportsUnreachableHost()
    {
        var handler = new StubHttpHandler(_ => throw new HttpRequestException("refused"));
        var client = new TranscriptionClient(new HttpClient(handler));
        var error = await Assert.ThrowsAsync<TranscriptionException>(() => client.TranscribeAsync(audioPath, Endpoint()));
        Assert.Equal(TranscriptionException.Unreachable("h").Message, error.Message);
    }
}
