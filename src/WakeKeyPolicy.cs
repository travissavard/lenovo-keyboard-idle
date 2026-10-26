public sealed class WakeKeyPolicy {
 readonly object gate=new object();
 bool dark;
 bool suppressFirstKey=true, prolongedHold=true;
 long darkSince,holdUntil;
 int suppressedKey=-1;
 public void Configure(bool suppress, bool hold) {
  lock(gate) {
   suppressFirstKey=suppress;
   prolongedHold=hold;
   if(!hold) holdUntil=0;
   // Finish consuming the release of any press already swallowed.
  }
 }
 public void SetDark(bool value,long now) {
  lock(gate) {
   if(value==dark) return;
   if(value) darkSince=now;
   else if(prolongedHold && now-darkSince>=15000) holdUntil=now+15000;
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
    if(suppressFirstKey) suppressedKey=key;
    if(prolongedHold) holdUntil=now+15000;
    dark=false;
    return suppressFirstKey;
   }
   return false;
  }
 }
 public bool IsHolding(long now) { lock(gate) { return now<holdUntil; } }
}
