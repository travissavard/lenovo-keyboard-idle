public sealed class WakeKeyPolicy {
 readonly object gate=new object();
 bool dark;
 long darkSince,holdUntil;
 int suppressedKey=-1;
 public void SetDark(bool value,long now) {
  lock(gate) {
   if(value==dark) return;
   if(value) darkSince=now;
   else if(now-darkSince>=15000) holdUntil=now+15000;
   dark=value;
  }
 }
 public bool ProcessKey(int key,bool down,long now) {
  lock(gate) {
   if(key==suppressedKey) {
    if(!down) suppressedKey=-1;
    return true;
   }
   if(down && dark && now-darkSince>=15000) {
    suppressedKey=key;
    holdUntil=now+15000;
    dark=false;
    return true;
   }
   return false;
  }
 }
 public bool IsHolding(long now) { lock(gate) { return now<holdUntil; } }
}
