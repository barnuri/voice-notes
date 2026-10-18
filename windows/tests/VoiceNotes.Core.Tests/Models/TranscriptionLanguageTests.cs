using VoiceNotes.Core.Models;

namespace VoiceNotes.Core.Tests.Models;

public sealed class TranscriptionLanguageTests
{
    [Fact]
    public void HebrewSendsHebrewCodeWithMixedLanguagePrompt()
    {
        Assert.Equal("he", TranscriptionLanguage.HebrewWithEnglish.Code);
        Assert.Contains("deploy", TranscriptionLanguage.HebrewWithEnglish.Prompt, StringComparison.Ordinal);
        Assert.Null(TranscriptionLanguage.English.Prompt);
        Assert.Null(TranscriptionLanguage.Auto.Prompt);
    }

    [Theory]
    [InlineData("english", "en")]
    [InlineData("auto", "auto")]
    [InlineData("hebrewWithEnglish", "he")]
    [InlineData("unknown", "he")]
    [InlineData(null, "he")]
    public void FromIdFallsBackToHebrew(string? id, string expectedCode)
    {
        Assert.Equal(expectedCode, TranscriptionLanguage.FromId(id).Code);
    }
}
