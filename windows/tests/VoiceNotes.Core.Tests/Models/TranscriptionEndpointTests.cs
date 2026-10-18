using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Tests.Models;

public sealed class TranscriptionEndpointTests
{
    private static TranscriptionEndpoint? Create(string baseUrl, string model = "m") =>
        TranscriptionEndpoint.Create(baseUrl, model, "", TranscriptionLanguage.HebrewWithEnglish);

    [Theory]
    [InlineData("http://127.0.0.1:8888/v1")]
    [InlineData("http://127.0.0.1:8888/v1/")]
    [InlineData(" http://127.0.0.1:8888/v1 ")]
    public void BuildsTranscriptionUrl(string baseUrl)
    {
        var endpoint = Create(baseUrl);
        Assert.NotNull(endpoint);
        Assert.Equal("http://127.0.0.1:8888/v1/audio/transcriptions", endpoint.Url.AbsoluteUri);
    }

    [Theory]
    [InlineData("")]
    [InlineData("127.0.0.1:8888")]
    [InlineData("ftp://host/v1")]
    [InlineData("http://")]
    [InlineData("http://192.168.1.5:8888/v1")]
    [InlineData("/v1")]
    public void RejectsInvalidBase(string baseUrl)
    {
        Assert.Null(Create(baseUrl));
    }

    [Theory]
    [InlineData("http://localhost:8888/v1")]
    [InlineData("http://[::1]:8888/v1")]
    [InlineData("https://box.example.ts.net/v1")]
    public void AllowsLoopbackHttpAndAnyHttps(string baseUrl)
    {
        Assert.NotNull(Create(baseUrl));
    }

    [Fact]
    public void RejectsEmptyModel()
    {
        Assert.Null(Create("https://h/v1", model: "  "));
    }

    [Fact]
    public void TrimsModelAndApiKey()
    {
        var endpoint = TranscriptionEndpoint.Create("https://h/v1", " m ", " k ", TranscriptionLanguage.English);
        Assert.NotNull(endpoint);
        Assert.Equal("m", endpoint.Model);
        Assert.Equal("k", endpoint.ApiKey);
    }
}
