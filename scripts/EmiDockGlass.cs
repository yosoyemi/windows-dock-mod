using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

namespace EmiDock
{
    internal static class Glass
    {
        private const int AccentAcrylic = 4;
        private const int WcaAccentPolicy = 19;
        private const int MarginX = 8;
        private const int MarginTop = 5;
        private const int MarginBottom = 6;
        private const int Radius = 16;

        // Light frosted glass (ABGR). Alpha 0x78 = visible glass, icons stay opaque.
        private const int GlassColorAbgr = unchecked((int)0x78FFF6EC);

        private static readonly Dictionary<long, long> LastSize = new Dictionary<long, long>();

        [STAThread]
        public static void Main()
        {
            bool created;
            Mutex mutex = new Mutex(true, "EmiDockGlass.Win10", out created);
            if (!created)
            {
                return;
            }

            try
            {
                Native.SetProcessDPIAware();
            }
            catch
            {
            }

            while (true)
            {
                try
                {
                    ApplyAll();
                }
                catch
                {
                }

                Thread.Sleep(700);
            }
        }

        private static void ApplyAll()
        {
            IntPtr tray = Native.FindWindow("Shell_TrayWnd", null);
            if (tray != IntPtr.Zero)
            {
                ApplyTo(tray);
            }

            IntPtr secondary = IntPtr.Zero;
            while (true)
            {
                secondary = Native.FindWindowEx(IntPtr.Zero, secondary, "Shell_SecondaryTrayWnd", null);
                if (secondary == IntPtr.Zero)
                {
                    break;
                }

                ApplyTo(secondary);
            }
        }

        private static void ApplyTo(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero || !Native.IsWindow(hwnd))
            {
                return;
            }

            Native.RECT rc;
            if (!Native.GetWindowRect(hwnd, out rc))
            {
                return;
            }

            int width = rc.Right - rc.Left;
            int height = rc.Bottom - rc.Top;
            if (width < 48 || height < 24)
            {
                return;
            }

            ExtendFrame(hwnd);
            ApplyAccent(hwnd, AccentAcrylic);
            ApplyRoundRegion(hwnd, width, height);
        }

        private static void ExtendFrame(IntPtr hwnd)
        {
            Native.MARGINS margins = new Native.MARGINS();
            margins.cxLeftWidth = -1;
            Native.DwmExtendFrameIntoClientArea(hwnd, ref margins);
        }

        private static void ApplyAccent(IntPtr hwnd, int accentState)
        {
            Native.AccentPolicy policy = new Native.AccentPolicy();
            policy.AccentState = accentState;
            policy.AccentFlags = 2;
            policy.GradientColor = GlassColorAbgr;
            policy.AnimationId = 0;

            int size = Marshal.SizeOf(policy);
            IntPtr policyPtr = Marshal.AllocHGlobal(size);
            try
            {
                Marshal.StructureToPtr(policy, policyPtr, false);
                Native.WindowCompositionAttributeData data = new Native.WindowCompositionAttributeData();
                data.Attribute = WcaAccentPolicy;
                data.Data = policyPtr;
                data.SizeOfData = size;
                Native.SetWindowCompositionAttribute(hwnd, ref data);
            }
            finally
            {
                Marshal.FreeHGlobal(policyPtr);
            }
        }

        private static void ApplyRoundRegion(IntPtr hwnd, int width, int height)
        {
            long key = hwnd.ToInt64();
            long packed = ((long)width << 32) | (uint)height;
            long previous;
            if (LastSize.TryGetValue(key, out previous) && previous == packed)
            {
                return;
            }

            int left = MarginX;
            int top = MarginTop;
            int right = width - MarginX;
            int bottom = height - MarginBottom;
            if (right - left < 32 || bottom - top < 16)
            {
                left = 2;
                top = 2;
                right = width - 2;
                bottom = height - 2;
            }

            IntPtr region = Native.CreateRoundRectRgn(left, top, right, bottom, Radius * 2, Radius * 2);
            if (region == IntPtr.Zero)
            {
                return;
            }

            Native.SetWindowRgn(hwnd, region, true);
            LastSize[key] = packed;
        }

        private static class Native
        {
            [DllImport("user32.dll", CharSet = CharSet.Unicode)]
            public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

            [DllImport("user32.dll", CharSet = CharSet.Unicode)]
            public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);

            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool IsWindow(IntPtr hWnd);

            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

            [DllImport("user32.dll")]
            public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

            [DllImport("user32.dll")]
            public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);

            [DllImport("gdi32.dll")]
            public static extern IntPtr CreateRoundRectRgn(int nLeftRect, int nTopRect, int nRightRect, int nBottomRect, int nWidthEllipse, int nHeightEllipse);

            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool SetProcessDPIAware();

            [DllImport("dwmapi.dll")]
            public static extern int DwmExtendFrameIntoClientArea(IntPtr hWnd, ref MARGINS pMarInset);

            [StructLayout(LayoutKind.Sequential)]
            public struct MARGINS
            {
                public int cxLeftWidth;
                public int cxRightWidth;
                public int cyTopHeight;
                public int cyBottomHeight;
            }

            [StructLayout(LayoutKind.Sequential)]
            public struct RECT
            {
                public int Left;
                public int Top;
                public int Right;
                public int Bottom;
            }

            [StructLayout(LayoutKind.Sequential)]
            public struct AccentPolicy
            {
                public int AccentState;
                public int AccentFlags;
                public int GradientColor;
                public int AnimationId;
            }

            [StructLayout(LayoutKind.Sequential)]
            public struct WindowCompositionAttributeData
            {
                public int Attribute;
                public IntPtr Data;
                public int SizeOfData;
            }
        }
    }
}
