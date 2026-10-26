using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
public sealed class KeyboardActivityClock : IDisposable {
 delegate IntPtr HookProc(int code,IntPtr wParam,IntPtr lParam);
 [StructLayout(LayoutKind.Sequential)] struct KEYDATA { public uint Key,Scan,Flags,Time; public IntPtr Extra; }
 [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr Window; public uint Message; public IntPtr WParam,LParam; public uint Time; public int X,Y; public uint Private; }
 [DllImport("user32.dll",SetLastError=true)] static extern IntPtr SetWindowsHookEx(int type,HookProc proc,IntPtr module,uint thread);
 [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
 [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook,int code,IntPtr wParam,IntPtr lParam);
 [DllImport("user32.dll",SetLastError=true)] static extern bool PostThreadMessage(uint thread,uint message,IntPtr wParam,IntPtr lParam);
 [DllImport("user32.dll")] static extern bool PeekMessage(out MSG message,IntPtr window,uint min,uint max,uint remove);
 [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
 [DllImport("kernel32.dll",CharSet=CharSet.Auto)] static extern IntPtr GetModuleHandle(string name);
 readonly WakeKeyPolicy policy=new WakeKeyPolicy();
 readonly ManualResetEventSlim ready=new ManualResetEventSlim(false);
 readonly Thread thread;
 readonly HookProc callback;
 IntPtr hook;
 uint threadId;
 long lastKeyboardTime;
 Exception startupError;
 public static long Now() { return (long)(Stopwatch.GetTimestamp()*1000.0/Stopwatch.Frequency); }
 public KeyboardActivityClock() {
  lastKeyboardTime=Now();
  callback=OnKey;
  thread=new Thread(Run);
  thread.IsBackground=true;
  thread.Name="Keyboard backlight wake filter";
  thread.SetApartmentState(ApartmentState.STA);
  thread.Start();
  if(!ready.Wait(5000)) throw new TimeoutException("Keyboard wake filter did not start.");
  if(startupError!=null) throw new InvalidOperationException("Keyboard wake filter failed.",startupError);
 }
 void Run() {
  try {
   threadId=GetCurrentThreadId();
   MSG message; PeekMessage(out message,IntPtr.Zero,0,0,0);
   hook=SetWindowsHookEx(13,callback,GetModuleHandle(null),0);
   if(hook==IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
   ready.Set();
   Application.Run();
  } catch(Exception error) { startupError=error; ready.Set(); }
  finally { if(hook!=IntPtr.Zero) {UnhookWindowsHookEx(hook);hook=IntPtr.Zero;} }
 }
 IntPtr OnKey(int code,IntPtr wParam,IntPtr lParam) {
  if(code>=0) {
   int message=wParam.ToInt32();
   bool down=message==0x100 || message==0x104;
   bool up=message==0x101 || message==0x105;
   if(down||up) {
    var data=(KEYDATA)Marshal.PtrToStructure(lParam,typeof(KEYDATA));
    long now=Now();
    Interlocked.Exchange(ref lastKeyboardTime,now);
    // Injected input remains usable and is never swallowed by the wake filter.
    if((data.Flags&0x10)==0 && policy.ProcessKey((int)data.Key,down,now)) return new IntPtr(1);
   }
  }
  return CallNextHookEx(hook,code,wParam,lParam);
 }
 public uint Milliseconds() { return (uint)Math.Min(uint.MaxValue,Math.Max(0,Now()-Interlocked.Read(ref lastKeyboardTime))); }
 public void SetDark(bool dark) { policy.SetDark(dark,Now()); }
 public bool IsHolding() { return policy.IsHolding(Now()); }
 public void Dispose() {
  if(thread.IsAlive) {PostThreadMessage(threadId,0x12,IntPtr.Zero,IntPtr.Zero);thread.Join(5000);}
  ready.Dispose();
 }
}
