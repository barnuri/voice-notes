using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using VoiceNotes.Windows.Native;

namespace VoiceNotes.Windows.Services;

internal static unsafe class ApiKeyProtector
{
    internal static string Protect(string apiKey)
    {
        if (apiKey.Length == 0)
        {
            return "";
        }
        return Convert.ToBase64String(Transform(Encoding.UTF8.GetBytes(apiKey), protect: true));
    }

    internal static string Unprotect(string protectedApiKey)
    {
        if (protectedApiKey.Length == 0)
        {
            return "";
        }
        return Encoding.UTF8.GetString(Transform(Convert.FromBase64String(protectedApiKey), protect: false));
    }

    private static byte[] Transform(byte[] input, bool protect)
    {
        fixed (byte* inputBytes = input)
        {
            var dataIn = new DataBlob { Length = (uint)input.Length, Data = (nint)inputBytes };
            var dataOut = default(DataBlob);
            var succeeded = protect
                ? Crypt32.CryptProtectData(&dataIn, 0, null, 0, 0, Crypt32.ProtectUiForbidden, &dataOut)
                : Crypt32.CryptUnprotectData(&dataIn, 0, null, 0, 0, Crypt32.ProtectUiForbidden, &dataOut);
            if (!succeeded)
            {
                throw new Win32Exception(Marshal.GetLastPInvokeError());
            }
            try
            {
                return new ReadOnlySpan<byte>((void*)dataOut.Data, (int)dataOut.Length).ToArray();
            }
            finally
            {
                Kernel32.LocalFree(dataOut.Data);
            }
        }
    }
}
