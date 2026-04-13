# parsec-vdd-add.ps1 — Add a Parsec virtual display and keep it alive
# Press Ctrl+C to remove the display and exit

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.Win32.SafeHandles;

public static class ParsecVDD
{
    // IOCTL codes
    const uint IOCTL_ADD    = 0x0022e004;
    const uint IOCTL_REMOVE = 0x0022a008;
    const uint IOCTL_UPDATE = 0x0022a00c;

    // Device interface GUID
    static readonly Guid ADAPTER_GUID = new Guid(0x00b41627, 0x04c4, 0x429e, 0xa2, 0x6e, 0x02, 0x65, 0xcf, 0x50, 0xc8, 0xfa);

    // SetupAPI
    [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr SetupDiGetClassDevs(ref Guid classGuid, IntPtr enumerator, IntPtr hwndParent, uint flags);

    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiEnumDeviceInterfaces(IntPtr devInfoSet, IntPtr devInfoData, ref Guid interfaceClassGuid, uint memberIndex, ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData);

    [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr devInfoSet, ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData, IntPtr deviceInterfaceDetailData, uint deviceInterfaceDetailDataSize, out uint requiredSize, IntPtr deviceInfoData);

    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr devInfoSet);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern SafeFileHandle CreateFile(string fileName, uint desiredAccess, uint shareMode, IntPtr securityAttributes, uint creationDisposition, uint flagsAndAttributes, IntPtr templateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(SafeFileHandle hDevice, uint ioControlCode, byte[] inBuffer, uint inBufferSize, byte[] outBuffer, uint outBufferSize, out uint bytesReturned, IntPtr overlapped);

    const uint DIGCF_PRESENT = 0x02;
    const uint DIGCF_DEVICEINTERFACE = 0x10;
    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint OPEN_EXISTING = 3;

    [StructLayout(LayoutKind.Sequential)]
    struct SP_DEVICE_INTERFACE_DATA
    {
        public uint cbSize;
        public Guid InterfaceClassGuid;
        public uint Flags;
        public IntPtr Reserved;
    }

    static SafeFileHandle OpenDevice()
    {
        Guid guid = ADAPTER_GUID;
        IntPtr devInfo = SetupDiGetClassDevs(ref guid, IntPtr.Zero, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
        if (devInfo == (IntPtr)(-1))
            throw new Exception("SetupDiGetClassDevs failed");

        try
        {
            SP_DEVICE_INTERFACE_DATA ifData = new SP_DEVICE_INTERFACE_DATA();
            ifData.cbSize = (uint)Marshal.SizeOf(ifData);

            if (!SetupDiEnumDeviceInterfaces(devInfo, IntPtr.Zero, ref guid, 0, ref ifData))
                throw new Exception("No Parsec VDD device interface found");

            // Get required size
            uint requiredSize;
            SetupDiGetDeviceInterfaceDetail(devInfo, ref ifData, IntPtr.Zero, 0, out requiredSize, IntPtr.Zero);

            // Allocate and set cbSize (6 on x64, 5 on x86 for the fixed part)
            IntPtr detailData = Marshal.AllocHGlobal((int)requiredSize);
            try
            {
                // cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA) which is 8 on x64 due to alignment
                Marshal.WriteInt32(detailData, IntPtr.Size == 8 ? 8 : 5);

                if (!SetupDiGetDeviceInterfaceDetail(devInfo, ref ifData, detailData, requiredSize, out requiredSize, IntPtr.Zero))
                    throw new Exception("SetupDiGetDeviceInterfaceDetail failed: " + Marshal.GetLastWin32Error());

                // Device path starts at offset 4
                string devicePath = Marshal.PtrToStringAuto(detailData + 4);
                Console.WriteLine("Device path: " + devicePath);

                SafeFileHandle handle = CreateFile(devicePath, GENERIC_READ | GENERIC_WRITE, 0, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
                if (handle.IsInvalid)
                    throw new Exception("CreateFile failed: " + Marshal.GetLastWin32Error());

                return handle;
            }
            finally
            {
                Marshal.FreeHGlobal(detailData);
            }
        }
        finally
        {
            SetupDiDestroyDeviceInfoList(devInfo);
        }
    }

    static int IoControl(SafeFileHandle handle, uint code, byte[] input)
    {
        byte[] outBuf = new byte[32];
        uint returned;
        byte[] inBuf = input ?? new byte[32];

        if (!DeviceIoControl(handle, code, inBuf, (uint)inBuf.Length, outBuf, (uint)outBuf.Length, out returned, IntPtr.Zero))
        {
            int err = Marshal.GetLastWin32Error();
            return -err;
        }

        // Return first byte of output as the display index
        return (returned > 0) ? (int)outBuf[0] : 0;
    }

    public static int AddDisplay(SafeFileHandle handle)
    {
        return IoControl(handle, IOCTL_ADD, null);
    }

    public static void RemoveDisplay(SafeFileHandle handle, int index)
    {
        byte[] input = new byte[32];
        // 16-bit big-endian index
        input[0] = (byte)((index >> 8) & 0xFF);
        input[1] = (byte)(index & 0xFF);
        IoControl(handle, IOCTL_REMOVE, input);
    }

    public static void Update(SafeFileHandle handle)
    {
        IoControl(handle, IOCTL_UPDATE, null);
    }

    public static SafeFileHandle Open()
    {
        return OpenDevice();
    }
}
"@ -ReferencedAssemblies System.Runtime.InteropServices

# Open device
$handle = [ParsecVDD]::Open()
Write-Host "Opened Parsec VDD device"

# Add a virtual display
$index = [ParsecVDD]::AddDisplay($handle)
Write-Host "Added virtual display at index: $index"

# Keep-alive loop (must ping every <100ms)
Write-Host "Keeping display alive... Press Ctrl+C to stop and remove display."
try {
    while ($true) {
        [ParsecVDD]::Update($handle)
        Start-Sleep -Milliseconds 90
    }
}
finally {
    Write-Host "`nRemoving virtual display $index..."
    [ParsecVDD]::RemoveDisplay($handle, $index)
    $handle.Close()
    Write-Host "Done."
}
