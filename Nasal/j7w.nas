# J7W Shinden
# This script is based on the one for A6M2
var force = 1.0;
var alt_m = 0.0;
var fdm_ok = 0;
toggle_canopy = func{
}

setlistener("/sim/signals/fdm-initialized", func {
  setprop("/instrumentation/altimeter/indicated-altitude-m",0.0);
  setprop("/engines/engine/cyl-temp",0.0);
  fdm_ok=1;
});

updates = func{
  setprop("/instrumentation/altimeter/indicated-altitude-m", getprop("/instrumentation/altimeter/indicated-altitude-ft") * 0.3048);
  if(getprop("/engines/engine/running") != 0) {
    interpolate("/engines/engine/cyl-temp", 0.5 + (getprop("/controls/engines/engine/throttle")* 0.5), 150);
  } else {
    interpolate("/engines/engine/cyl-temp", 0.0, 500);
  }
  if (getprop("/engines/engine/boost-gauge-inhg") != nil) {
    setprop("/engines/engine/boost-gauge-mmhg", getprop("/engines/engine/boost-gauge-inhg") * 25.4);
  } else {
    if (getprop("/engines/engine/mp-osi") != nil) {
      interpolate("/engines/engine/boost-gauge-mmhg", getprop("/engines/engine/mp-osi") * 25.4 - 750.006168, 0.2);
    }
  }
  force = getprop("/accelerations/pilot-g");
  if(force == nil) {force = 1.0;}
  eyepoint = getprop("sim/view/config/y-offset-m") +0.01;
  eyepoint -= (force * 0.01);
  if(getprop("/sim/current-view/view-number") < 1){
    setprop("/sim/current-view/y-offset-m",eyepoint);
  }
  registerTimer();    
}


registerTimer = func {
    settimer(updates, 0);
}

setlistener("/controls/canopy/opened", func {
    var position = cmdarg().getValue();
    interpolate("/controls/canopy/position-norm", position, 2);
  },1);

registerTimer();

