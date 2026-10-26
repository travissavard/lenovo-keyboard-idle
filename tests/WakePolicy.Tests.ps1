$ErrorActionPreference='Stop'
if(-not(Test-Path (Join-Path $PSScriptRoot '..\src\WakeKeyPolicy.cs'))){throw 'FAIL: long-dark wake policy is missing.'}
Add-Type -Path (Join-Path $PSScriptRoot '..\src\WakeKeyPolicy.cs')
$p=New-Object WakeKeyPolicy
$p.SetDark($true,0)
if($p.ProcessKey(65,$true,14999)){throw 'Short pause swallowed a key.'}
$p.SetDark($false,14999)
if($p.IsHolding(15000)){throw 'Short pause started prolonged illumination.'}
$p.SetDark($true,20000)
if(-not $p.ProcessKey(65,$true,35000)){throw 'First key after 15 seconds dark was not swallowed.'}
if(-not $p.ProcessKey(65,$true,35001)){throw 'Wake key repeat leaked.'}
if(-not $p.ProcessKey(65,$false,35002)){throw 'Wake key release leaked.'}
if($p.ProcessKey(66,$true,35003)){throw 'Second key was swallowed.'}
if(-not $p.IsHolding(49999)){throw '15-second hold ended early.'}
if($p.IsHolding(50000)){throw '15-second hold did not expire.'}
$p.SetDark($true,51000)
if($p.ProcessKey(67,$true,52000)){throw 'Normal use after hold swallowed key.'}
$p.SetDark($false,52000)
$p.SetDark($true,60000)
if(-not $p.ProcessKey(68,$true,75000)){throw 'Next long pause did not rearm.'}
$p.ProcessKey(68,$false,75001) | Out-Null
$p.SetDark($true,90000)
$p.SetDark($false,105000)
if(-not $p.IsHolding(119999)){throw 'Mouse wake after long pause did not hold.'}
if($p.ProcessKey(69,$true,105001)){throw 'Keyboard after mouse wake was swallowed.'}
'PASS: threshold, first press/repeat/release, next key, 15-second hold, normal use, rearm, mouse wake.'

# Independent switches must work in all four combinations.
foreach($suppress in @($false,$true)) {
 foreach($hold in @($false,$true)) {
  $q=New-Object WakeKeyPolicy
  $q.Configure($suppress,$hold)
  $q.SetDark($true,0)
  if($q.ProcessKey(65,$true,15000) -ne $suppress){throw "Wrong first-key handling: suppress=$suppress hold=$hold"}
  if($q.IsHolding(15001) -ne $hold){throw "Wrong hold: suppress=$suppress hold=$hold"}
  if($q.ProcessKey(65,$false,15002) -ne $suppress){throw 'Wake key release mismatch.'}
  if($q.ProcessKey(66,$true,15003)){throw 'Second key was swallowed.'}
  if($q.IsHolding(30000)){throw 'Hold did not expire.'}
 }
}
$q=New-Object WakeKeyPolicy
$q.SetDark($true,0)
$q.ProcessKey(65,$true,15000) | Out-Null
$q.Configure($false,$false)
if($q.IsHolding(15001)){throw 'Disabling hold did not cancel it immediately.'}
if(-not $q.ProcessKey(65,$false,15002)){throw 'Release of an already consumed press leaked after disabling.'}
$q.SetDark($true,20000)
if($q.ProcessKey(65,$true,35000)){throw 'Disabling first-key swallowing did not persist.'}
if($q.IsHolding(35001)){throw 'Disabling hold did not persist.'}
'PASS: both switches independent; disabling hold cancels it; consumed-key release stays paired.'
