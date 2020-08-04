$pinvokeCode = @"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using Microsoft.Win32;

//Note to self:checkout https://github.com/lihas/windows-DPI-scaling-sample/blob/master/DPIHelper/DpiHelper.cpp
//https://stackoverflow.com/questions/35233182/how-can-i-change-windows-10-display-scaling-programmatically-using-c-sharp

namespace Displayhelper
{

    enum DISP_CHANGE : int
    {
        Successful = 0,
        Restart = 1,
        Failed = -1,
        BadMode = -2,
        NotUpdated = -3,
        BadFlags = -4,
        BadParam = -5,
        BadDualView = -6
    }

    public class DisplayInfo
    {
        public DisplayInfo()
        { 
            SystemEvents.DisplaySettingsChanged += SystemEvents_DisplaySettingsChanged;
        }

        private void SystemEvents_DisplaySettingsChanged(object sender, EventArgs e)
        {
            //System.Windows.Forms.MessageBox.Show("Main change");
            //Native caller = new Native();
            //caller.EnumMonitors();
            //var testa = "kasjdksd";
        }
        
        public const int ENUM_CURRENT_SETTINGS = -1;
        public const int ENUM_REGISTRY_SETTINGS = 0;
        public const int CDS_UPDATEREGISTRY = 0x01;
        public const int CDS_TEST = 0x02;
        public const int DISP_CHANGE_SUCCESSFUL = 0;
        public const int DISP_CHANGE_RESTART = 1;
        public const int DISP_CHANGE_FAILED = -1;

        public static HandleRef nullHandleRef = new HandleRef(null, IntPtr.Zero);
        internal static List<DisplayMonitor> Monitors = new List<DisplayMonitor>();
        internal static List<MonitorInfoWithHandle> _monitorInfos = new List<MonitorInfoWithHandle>();
        

        #region enums/structs


        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        internal struct DISPLAY_DEVICE
        {
            [MarshalAs(UnmanagedType.U4)]
            public int cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string DeviceString;
            [MarshalAs(UnmanagedType.U4)]
            public DisplayDeviceStateFlags StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string DeviceKey;
        }

        [Flags()]
        public enum DisplayDeviceStateFlags : int
        {
            AttachedToDesktop = 0x1,
            MultiDriver = 0x2,

            PrimaryDevice = 0x4,

            MirroringDriver = 0x8,

            VGACompatible = 0x16,

            Removable = 0x20,

            ModesPruned = 0x8000000,
            Remote = 0x4000000,
            Disconnect = 0x2000000
        }

        [Flags()]
        public enum ChangeDisplaySettingsFlags : uint
        {
            CDS_NONE = 0,
            CDS_UPDATEREGISTRY = 0x00000001,
            CDS_TEST = 0x00000002,
            CDS_FULLSCREEN = 0x00000004,
            CDS_GLOBAL = 0x00000008,
            CDS_SET_PRIMARY = 0x00000010,
            CDS_VIDEOPARAMETERS = 0x00000020,
            CDS_ENABLE_UNSAFE_MODES = 0x00000100,
            CDS_DISABLE_UNSAFE_MODES = 0x00000200,
            CDS_RESET = 0x40000000,
            CDS_RESET_EX = 0x20000000,
            CDS_NORESET = 0x10000000
        }

        public enum DpiType
        {
            Effective = 0,
            Angular = 1,
            Raw = 2,
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct Rect
        {
            public int left;
            public int top;
            public int right;
            public int bottom;
        }

        [Flags()]
        public enum DM : int
        {
            Orientation = 0x1,
            PaperSize = 0x2,
            PaperLength = 0x4,
            PaperWidth = 0x8,
            Scale = 0x10,
            Position = 0x20,
            NUP = 0x40,
            DisplayOrientation = 0x80,
            Copies = 0x100,
            DefaultSource = 0x200,
            PrintQuality = 0x400,
            Color = 0x800,
            Duplex = 0x1000,
            YResolution = 0x2000,
            TTOption = 0x4000,
            Collate = 0x8000,
            FormName = 0x10000,
            LogPixels = 0x20000,
            BitsPerPixel = 0x40000,
            PelsWidth = 0x80000,
            PelsHeight = 0x100000,
            DisplayFlags = 0x200000,
            DisplayFrequency = 0x400000,
            ICMMethod = 0x800000,
            ICMIntent = 0x1000000,
            MediaType = 0x2000000,
            DitherType = 0x4000000,
            PanningWidth = 0x8000000,
            PanningHeight = 0x10000000,
            DisplayFixedOutput = 0x20000000
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DEVMODE1
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string dmDeviceName;
            public short dmSpecVersion;
            public short dmDriverVersion;
            public short dmSize;
            public short dmDriverExtra;
            //public int dmFields;
            public DM dmFields;
            public short dmOrientation;
            public short dmPaperSize;
            public short dmPaperLength;
            public short dmPaperWidth;
            public short dmScale;
            public short dmCopies;
            public short dmDefaultSource;
            public short dmPrintQuality;
            public short dmColor;
            public short dmDuplex;
            public short dmYResolution;
            public short dmTTOption;
            public short dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string dmFormName;
            public short dmLogPixels;
            public short dmBitsPerPel;
            public int dmPelsWidth;
            public int dmPelsHeight;
            public int dmDisplayFlags;
            public int dmDisplayFrequency;
            public int dmICMMethod;
            public int dmICMIntent;
            public int dmMediaType;
            public int dmDitherType;
            public int dmReserved1;
            public int dmReserved2;
            public int dmPanningWidth;
            public int dmPanningHeight;
        };

        #endregion

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto, Pack = 4)]
        internal class MONITORINFOEX
        {
            internal int cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));
            internal Rect rcMonitor = new Rect();
            internal Rect rcWork = new Rect();
            internal int dwFlags = 0;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
            internal char[] szDevice = new char[32];
        }

        public class MonitorList : List<DisplayMonitor>
        {

            public MonitorList monitorList()
            {
                List<DisplayMonitor> monitorList = new List<DisplayMonitor>();
                foreach (var mon in Monitors)
                {
                    this.Add(mon);
                }
                return this;
            }
        }

        internal class MonitorInfoWithHandle
        {
            /// <summary>
            /// Gets the monitor handle.
            /// </summary>
            /// <value>
            /// The monitor handle.
            /// </value>
            /// 
            public string MonitorName { get; private set; }
            public IntPtr MonitorHandle { get; private set; }

            /// <summary>
            /// Gets the monitor information.
            /// </summary>
            /// <value>
            /// The monitor information.
            /// </value>
            public MONITORINFOEX MonitorInfo { get; private set; }

            /// <summary>
            /// Initializes a new instance of the <see cref="MonitorInfoWithHandle"/> class.
            /// </summary>
            /// <param name="monitorHandle">The monitor handle.</param>
            /// <param name="monitorInfo">The monitor information.</param>
            public MonitorInfoWithHandle(string monitorDisplayName, IntPtr monitorHandle, MONITORINFOEX monitorInfo)
            {
                MonitorHandle = monitorHandle;
                MonitorInfo = monitorInfo;
                MonitorName = monitorDisplayName;
            }
        }

        public class DisplayMonitor
        {
            private string name;
            private int width;
            private int height;
            private int dpiX;
            private int dpiY;
            private int logicalWidth;
            private int logicalHeight;
            private float scale;
            private IntPtr handle;
            private static DisplayMonitor dispMon;
            private string state;

            public virtual string Connected
            {
                
                get
                {
                    Native caller = new Native();
                    var testa=caller.EnumMonitors();
                    //System.Windows.Forms.MessageBox.Show("EnumMonitors res: " + testa.ToString());
                    dispMon = new DisplayMonitor(this.name, this.width, this.height, this.dpiX, this.dpiY, this.logicalWidth, this.logicalHeight);
                    bool done = false;
                    var sksdhdf=this.Name;
                    //System.Windows.Forms.MessageBox.Show("In Instance of DisplayMonitor");

                    try
                    {
                        var before = done;
                        done=RefreshInstance();
                        //System.Windows.Forms.MessageBox.Show("Return from Refresh: " + done.ToString() + " Before: " + before.ToString());
                    }
                    catch
                    {
                        //System.Windows.MessageBox.Show("Error in 'Instance'");
                    }

                    if (done == false)
                    {
                        dispMon = null;
                    }

                    //System.Windows.Forms.MessageBox.Show("done in Instance: " + done.ToString());
                    return done.ToString();

                }
            }
            public DisplayMonitor(string name, int width, int height, int dpiX, int dpiY, int logicalWidth, int logicalHeight)
            {
                this.name = name;
                this.width = width;
                this.height = height;
                this.dpiX = dpiX;
                this.dpiY = dpiY;
                this.logicalWidth = logicalWidth;
                this.logicalHeight = logicalHeight;
                this.scale = GetScale();
                CreateMonitorInfoWithHwnd();
                this.SetHandle();
                //DisplayMonitor.test();
                //this.resList = GetMonitorResolutions();



            }

            
            public virtual string Name
            {
                get {return name;}
                internal set { name = value; }
            }

            public virtual int Width
            {
                get { return width; }
                internal set { width = value; }
            }

            public virtual int Height
            {
                get { return height; }
                internal set { height = value; }
            }

            public virtual int LogicalWidth
            {
                get { return logicalWidth; }
                internal set { logicalWidth = value; }
            }

            public virtual int LogicalHeight
            {
                get { return logicalHeight; }
                internal set { logicalHeight = value; }
            }

            public virtual float Scale
            {
                get { return GetScale(); }
                internal set { scale = value; }
            }

            /*
            public Dictionary<string, Resolution> GetResolutions()
            {
                return null;
                return GetMonitorResolutions();
            }
            */

            public List<Resolution> GetResolutionsList()
            {
                return GetMonitorResolutions();
            }

            public System.Collections.ArrayList GetAllDPITypes()
            {
                var ret = GetDPIsForCurrentMonitor();
                return ret;
            }

            public bool RefreshInstance()
            {
                    var done = false;
                    var i = 0;
                    try
                    {
                        i++;
                        if (i <= 3)
                        {
                        done=UpdateInstance();
                        //System.Windows.MessageBox.Show("Done: " + done.ToString());
                        }
                    }
                    catch
                    {
                        //System.Windows.Forms.MessageBox.Show("error during RefreshInstance");
                    }
                
                return done;
            }

            internal void SetHandle()
            {
                MonitorInfoWithHandle MonInfoWithHwnd = _monitorInfos.Find(i => i.MonitorName == name);
                if (MonInfoWithHwnd != null)
                {
                    this.handle = MonInfoWithHwnd.MonitorHandle;
                    //System.Windows.Forms.MessageBox.Show(this.handle.ToString());
                }
            }

            internal bool UpdateInstance()
            {
                //System.Windows.Forms.MessageBox.Show("Upd");
                //DisplayInfo DpiHelp = new DisplayInfo();
                //GetDisplayMonitors();
                //var monitorCount = Monitors.Count();
                //var formscount=System.Windows.Forms.Screen.AllScreens.Count();
                MonitorInfoWithHandle MonInfoWithHwnd = _monitorInfos.Find(i => i.MonitorName == name);
                 if (MonInfoWithHwnd != null)
                 {


                    Native Caller = new Native();
                    DisplayInfo.MONITORINFOEX mon_info = new DisplayInfo.MONITORINFOEX();
                    mon_info.cbSize = (int)Marshal.SizeOf(mon_info);
                    try
                    {
                        //System.Windows.Forms.MessageBox.Show("in try for: " + name);
                        Native.GetMonitorInfo(new HandleRef(null, MonInfoWithHwnd.MonitorHandle), mon_info);
                        //System.Windows.Forms.MessageBox.Show("After GetMonitorInfo: " + name);
                        string DisplayName = new string(@mon_info.szDevice);
                        int[] DisplayRes = Caller.GetCurrentResolution(DisplayName);
                        int logicalW = (mon_info.rcMonitor.right - mon_info.rcMonitor.left);
                        int logicalH = (mon_info.rcMonitor.bottom - mon_info.rcMonitor.top);
                        this.Width = DisplayRes[0];
                        this.Height = DisplayRes[1];
                        this.LogicalHeight = logicalH;
                        this.LogicalWidth = logicalW;
                        this.Scale = GetScale();
                    }
                    catch (Exception e)
                    {
                        //System.Windows.Forms.MessageBox.Show("Error: " + name);
                        //System.Windows.Forms.MessageBox.Show(e.Message);
                        CreateMonitorInfoWithHwnd();
                        UpdateInstance();
                    }
                }
                else
                {
                    //System.Windows.Forms.MessageBox.Show("Handle for " + name + " is null");
                    //System.Windows.Forms.MessageBox.Show("Monitor count: " + Monitors.Count().ToString());
                    this.state = "Disconnected";
                    this.Width = 0;
                    this.Height = 0;
                    this.LogicalHeight = 0;
                    this.LogicalWidth = 0;
                    this.Scale = 0;
                    return false;
                    
                }
                return true;
            }

            internal System.Collections.ArrayList GetDPIsForCurrentMonitor()
            {
                System.Collections.ArrayList ret = new System.Collections.ArrayList();

                int AngdpiX = 0;
                int AngdpiY = 0;
                int EffdpiX = 0;
                int EffdpiY = 0;
                int RawdpiX = 0;
                int RawdpiY = 0;

                MonitorInfoWithHandle MonInfoWithHwnd = _monitorInfos.Find(i => i.MonitorName == name);
                var mi = new MONITORINFOEX();

                if (MonInfoWithHwnd == null)
                {
                    CreateMonitorInfoWithHwnd();
                    MonInfoWithHwnd = _monitorInfos.Find(i => i.MonitorName == name);
                }

                if (MonInfoWithHwnd != null)
                {

                    //MonitorInfoWithHandle MonInfoWithHwnd = GetDPIsForMonitor(this.Name);

                    Native.GetDpi(MonInfoWithHwnd.MonitorHandle, DpiType.Angular, out AngdpiX, out AngdpiY);
                    DPIValue Angular = new DPIValue(AngdpiX, AngdpiY, DpiType.Angular);
                    ret.Add(Angular);

                    Native.GetDpi(MonInfoWithHwnd.MonitorHandle, DpiType.Effective, out EffdpiX, out EffdpiY);
                    DPIValue Effective = new DPIValue(EffdpiX, EffdpiY, DpiType.Effective);
                    ret.Add(Effective);

                    Native.GetDpi(MonInfoWithHwnd.MonitorHandle, DpiType.Raw, out RawdpiX, out RawdpiY);
                    DPIValue Raw = new DPIValue(RawdpiX, RawdpiY, DpiType.Raw);
                    ret.Add(Raw);
                }
                return ret;
            }




            internal bool CreateMonitorInfoWithHwnd()
            {
                _monitorInfos.Clear();
                //_monitorInfos = new List<MonitorInfoWithHandle>();
                Native.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, CreateInfoWHandleCallback, IntPtr.Zero);
                //System.Windows.Forms.MessageBox.Show("_monitorInfos count: " + _monitorInfos.Count().ToString());
                return true;
            }


            internal bool CreateInfoWHandleCallback(IntPtr hMonitor, IntPtr hdcMonitor, ref Rect lprcMonitor, IntPtr dwData)
            {

                var mi = new MONITORINFOEX();
                mi.cbSize = (int)Marshal.SizeOf(mi);
                Native.GetMonitorInfo(new HandleRef(null, hMonitor), mi);
                string DisplayName = new string(@mi.szDevice).Replace("\0", "");
                _monitorInfos.Add(new MonitorInfoWithHandle(DisplayName, hMonitor, mi));
                return true;
            }

            /*
            internal MonitorInfoWithHandle GetDPIsForMonitor(string name)
            {
                var Monitor=_monitorInfos.Find(i => i.MonitorName == name);
                if (Monitor != null)
                {
                    var mi = new DisplayInfo.MONITORINFOEX();
                    Native.GetMonitorInfo(new HandleRef(null, Monitor.MonitorHandle), mi);
                    string DisplayName = new string(@mi.szDevice).Replace("\0", "");
                }
                //resolutions.Find(i => i.Name == TempRes.Name);
                Native.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, MonitorEnum2, IntPtr.Zero);
                foreach (MonitorInfoWithHandle moninfo in _monitorInfos)
                {
                    string DisplayName = new string(@moninfo.MonitorInfo.szDevice);
                    var sksjdjdfdf = "";
                    if (DisplayName.Replace("\0", "") == name)
                    {
                        return moninfo;
                    }
                }
                return null;

                
                int dpx = 0;
                int dpy = 0;
                var retvalue = GetDpiForWindow(hMonitor);
                GetDpi(hMonitor, DisplayInfo.DpiType.Effective, out dpx, out dpy);
                

            }*/

            /*
            internal bool MonitorEnum2(IntPtr hMonitor, IntPtr hdcMonitor, ref Rect lprcMonitor, IntPtr dwData)
            {
                //Native Caller = new Native();

                var mi = new MONITORINFOEX();
                //DisplayInfo.MONITORINFOEX mon_info = new DisplayInfo.MONITORINFOEX();
                mi.cbSize = (int)Marshal.SizeOf(mi);
                //21:02
                //Caller.EnumMonitors();
                //Caller.GetMonitorInfo(hMonitor, ref mi);
                Native.GetMonitorInfo(new HandleRef(null, hMonitor), mi);
                string DisplayName = new string(@mi.szDevice).Replace("\0", "");
                // Add to monitor info
                _monitorInfos.Add(new MonitorInfoWithHandle(DisplayName, hMonitor, mi));
                return true;
            }
            */

            internal List<Resolution> GetMonitorResolutions()
            {
                var allScreens = System.Windows.Forms.Screen.AllScreens;
                //Dictionary<string, Resolution> tempres = new Dictionary<string, Resolution>();
                List<Resolution> tempres = new List<Resolution>();

                foreach (System.Windows.Forms.Screen screen in allScreens)
                {
                    if (screen.DeviceName == this.name)
                    {
                        DisplayInfo temp = new DisplayInfo();
                        tempres = temp.GetMonitorPossibleResolutions(screen);

                    }
                }
                return tempres;
            }

            /*
            public object GetLogicalResolution()
            {
                Native NativeCaller = new Native();
                var testar = NativeCaller.GetCurrentResolution(this.name);
                //var testar = GetCurrentResolution(this.name);
                object MonitorResolution = new { Width = testar[0], Height = testar[1] };
                return MonitorResolution;
            }
            */
            private float GetScale()
            {
                var ScaleOnBoot = (float)this.dpiX / 96;
                double Final = ((double)this.logicalHeight) / ScaleOnBoot;
                float curScale = (float)Math.Round(((float)this.height / (float)Final), 2);


                return curScale;
            }


        }

            public List<DisplayMonitor> GetDisplayMonitors()
            //public MonitorList GetDisplayMonitors()
            {
            //System.Windows.Forms.MessageBox.Show("in GetDisplayMonitors");
            Native Caller = new Native();
            var done = Caller.EnumMonitors();
            Caller = null;

            //return (new MonitorList().monitorList());
            return Monitors.ToList();
        }

        /*
        public bool GetMonitorResolution(System.Windows.Forms.Screen screen)
        {
            DEVMODE1 dm = new DEVMODE1();
            Native.EnumDisplaySettings(screen.DeviceName, DisplayInfo.ENUM_CURRENT_SETTINGS, ref dm);
            return true;
        }
        */

        internal List<Resolution> GetMonitorPossibleResolutions(System.Windows.Forms.Screen screen)
        {
            List<Resolution> resolutions = new List<Resolution>();
            Dictionary<string, Resolution> returnDict = new Dictionary<string, Resolution>();
            var index = -1;
            bool isValid = true;
            while (isValid == true)
            {
                index++;
                DEVMODE1 dm = new DEVMODE1();
                dm.dmFields = 0;
                var res = Native.EnumDisplaySettings(screen.DeviceName, index, ref dm);
                if (res != 1)
                {
                    break;
                }
                DM dmInfo = dm.dmFields;

                if (dm.dmDefaultSource == 0 & dm.dmPelsWidth >= 640 & dm.dmPelsHeight >= 480)
                {
                    string name = dm.dmPelsWidth.ToString() + "x" + dm.dmPelsHeight.ToString();

                    Resolution TempRes = new Resolution(name, dm.dmPelsWidth, dm.dmPelsHeight, dm.dmBitsPerPel);
                    //resolutions.Add(new Resolution(name, dm.dmPelsWidth, dm.dmPelsHeight,dm.dmBitsPerPel));
                    if (!returnDict.ContainsKey(name))
                    {
                        returnDict.Add(name, TempRes);
                    }
                    var AlreadyAdded = resolutions.Find(i => i.Name == TempRes.Name);
                    if (AlreadyAdded == null)
                    {
                        resolutions.Add(TempRes);
                    }


                }

            }
            if (resolutions.Count() > 16)
            {
                int start = resolutions.Count() - 16;
                resolutions = resolutions.GetRange(start, (resolutions.Count() - start));
            }
            return resolutions;
        }

    }

    internal class DPIValue
    {
        int dpiX = 0;
        int dpiY = 0;
        DisplayInfo.DpiType dpiType;

        public DPIValue(int dpiX, int dpiY, DisplayInfo.DpiType type)
        {
            this.dpiX = dpiX;
            this.dpiY = dpiY;
            this.dpiType = type;
        }
        public virtual string DpiType
        {
            get { return this.dpiType.ToString(); }
        }

        public virtual int DpiX
        {
            get { return this.dpiX; }
        }

        public virtual int DpiY
        {
            get { return this.dpiY; }
        }

    }

    public class Resolution
    {
        private string name;
        private int width;
        private int height;
        private int colordepth;

        public string Name
        {
            get { return this.name; }
        }
        public int Width
        {
            get { return this.width; }
        }

        public int Heigth
        {
            get { return this.height; }
        }

        public int Colordepth
        {
            get { return this.colordepth; }
        }

        public Resolution(string ObjectName, int Width, int Height, int ColorDepth)
        {
            name = ObjectName;
            this.name = ObjectName;
            this.width = Width;
            this.height = Height;
            this.colordepth = ColorDepth;
        }

    }

    internal class Native
    {
        [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hwnd);
        [DllImport("gdi32.dll")] static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
        [DllImport("user32.dll")] internal static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);
        [DllImport("user32.dll", CharSet = CharSet.Auto)] internal static extern bool GetMonitorInfo(HandleRef hmonitor, [In, Out]DisplayInfo.MONITORINFOEX info);
        [DllImport("user32.dll")] static extern int GetDpiForWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DisplayInfo.DEVMODE1 devMode);
        [DllImport("user32.dll")] static extern bool EnumDisplayDevices(string deviceName, uint iDevNum, ref DisplayInfo.DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);
        [DllImport("user32.dll")] public static extern DISP_CHANGE ChangeDisplaySettingsEx(string lpszDeviceName, ref DisplayInfo.DEVMODE1 lpDevMode, IntPtr hwnd, DisplayInfo.ChangeDisplaySettingsFlags dwflags, IntPtr lParam);

        //https://msdn.microsoft.com/en-us/library/windows/desktop/dd145062(v=vs.85).aspx
        [DllImport("User32.dll")] private static extern IntPtr MonitorFromPoint([In]System.Drawing.Point pt, [In]uint dwFlags);

        //https://msdn.microsoft.com/en-us/library/windows/desktop/dn280510(v=vs.85).aspx
        [DllImport("Shcore.dll")] private static extern IntPtr GetDpiForMonitor([In]IntPtr hmonitor, [In]DisplayInfo.DpiType dpiType, [Out]out int dpiX, [Out]out int dpiY);


        internal delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref DisplayInfo.Rect lprcMonitor, IntPtr dwData);

        internal bool EnumMonitors()
        {

            DisplayInfo.Monitors.Clear();
            EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, MonitorEnumCallBack, IntPtr.Zero);

            return true;
        }

        private bool MonitorEnumCallBack(IntPtr hMonitor, IntPtr hdcMonitor, ref DisplayInfo.Rect lprcMonitor, IntPtr dwData)
        {
            int dpx = 0;
            int dpy = 0;
            GetDpi(hMonitor, DisplayInfo.DpiType.Effective, out dpx, out dpy);
            DisplayInfo.MONITORINFOEX mon_info = new DisplayInfo.MONITORINFOEX();
            mon_info.cbSize = (int)Marshal.SizeOf(mon_info);
            GetMonitorInfo(new HandleRef(null, hMonitor), mon_info);
            string DisplayName = new string(@mon_info.szDevice);
            int[] DisplayRes = GetCurrentResolution(DisplayName);
            System.Drawing.Graphics g = System.Drawing.Graphics.FromHwnd(IntPtr.Zero);
            float FixScale = (float)dpx / 96;
            //Console.WriteLine(System.Windows.SystemParameters.PrimaryScreenHeight);
            //Console.WriteLine("FixScale: " + FixScale.ToString());
            //Console.WriteLine("mon_info.rcMonitor.right :" + mon_info.rcMonitor.right.ToString());
            //Console.WriteLine("mon_info.rcMonitor.left :" + mon_info.rcMonitor.left.ToString());
            int logicalW = (mon_info.rcMonitor.right - mon_info.rcMonitor.left);
            int logicalH = (mon_info.rcMonitor.bottom - mon_info.rcMonitor.top);
            //Console.WriteLine("LogW: " + logicalW.ToString());
            if (DisplayRes.Count() == 2)
            {
                string CleanedName = DisplayName.Replace("\0", "");
                DisplayInfo.DisplayMonitor tempMonitor = new DisplayInfo.DisplayMonitor(CleanedName, DisplayRes[0], DisplayRes[1], (int)dpx, (int)dpy, logicalW, logicalH);
                DisplayInfo.Monitors.Add(tempMonitor);
            }
            //System.Windows.MessageBox.Show("MonitorEnumCallBack Monitor count :" + DisplayInfo.Monitors.Count().ToString());
            ///Monitor info is stored in 'mon_info'
            return true;
        }

        public static void GetDpi(IntPtr hMonitor, DisplayInfo.DpiType dpiType, out int dpiX, out int dpiY)
        {
            GetDpiForMonitor(hMonitor, dpiType, out dpiX, out dpiY);
        }

        internal int[] GetCurrentResolution(string deviceName)
        {
            int[] returnValue = null;
            DisplayInfo.DEVMODE1 dm = GetDevMode1();
            if (0 != EnumDisplaySettings(deviceName, DisplayInfo.ENUM_CURRENT_SETTINGS, ref dm))
            {
                //int[] test = new int[]{ dm.dmPelsWidth, dm.dmPelsHeight};
                returnValue = new int[] { dm.dmPelsWidth, dm.dmPelsHeight };
            }
            return returnValue;
        }

        private static DisplayInfo.DEVMODE1 GetDevMode1()
        {
            DisplayInfo.DEVMODE1 dm = new DisplayInfo.DEVMODE1();
            dm.dmDeviceName = new String(new char[32]);
            dm.dmFormName = new String(new char[32]);
            dm.dmSize = (short)Marshal.SizeOf(dm);
            return dm;
        }

        internal List<DisplayInfo.DISPLAY_DEVICE> GetDisplayDevices()
        {
            List<DisplayInfo.DISPLAY_DEVICE> DispDevArray = new List<DisplayInfo.DISPLAY_DEVICE>();
            DisplayInfo.DISPLAY_DEVICE d = new DisplayInfo.DISPLAY_DEVICE();
            d.cb = Marshal.SizeOf(d);

            try
            {
                for (uint id = 0; EnumDisplayDevices(null, id, ref d, 0); id++)
                {
                    if ((d.StateFlags & DisplayInfo.DisplayDeviceStateFlags.AttachedToDesktop) != 0)
                    {

                        DispDevArray.Add(d);
                        string teststr = String.Format("{0}, {1}, {2}, {3}, {4}, {5}",
                              id,
                              d.DeviceName,
                              d.DeviceString,
                              d.StateFlags,
                              d.DeviceID,
                              d.DeviceKey
                              );

                        d.cb = Marshal.SizeOf(d);
                    }
                }
            }
            catch
            {

            }

            return DispDevArray;
        }
    }

}

"@

Add-Type $pinvokeCode -ReferencedAssemblies System.Drawing,PresentationFramework, System.Windows.Forms -PassThru -IgnoreWarnings | Out-Null


Function Get-Monitors
{
    $DisplayHelper=[Displayhelper.DisplayInfo]::new()
    return $($DisplayHelper.GetDisplayMonitors())
}