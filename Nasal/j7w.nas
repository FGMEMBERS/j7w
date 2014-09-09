# J7W Shinden
# This script is based on the one for A6M2

#
# Water Methanol Injection, maybe for some Japanese warbirds
#
WMInjection = {
  # 
  # new(rate)
  # rate: boost multiplier (0.0 = raw-boost to 1.0 to 2 * ras-boost)
  # 
  new : func(rate) {
    var obj = { parents : [WMInjection],
            capacity : 12.0,
            boost_rate : rate,
            active : 0,
            property : "/controls/engines/engine/water-methanol-injection", 
            gauge1 : "/instrumentation/water-methanol-injection/pump-pressure",
            gauge2 : "/instrumentation/water-methanol-injection/injection-pressure",
            min_pump_pressure : 0.3,
            max_pump_pressure : 1.6,
            min_injection_pressure : 0.8,
            max_injection_pressure : 15,
            pump_pressure : 0.0,
            injection_pressure : 0.0
          };
    setlistener("/sim/signals/fdm-initialized", func { obj.consume(); });
    setlistener("/sim/signals/reinit", func { obj.reset(); });
    obj.reset();
    return obj;
  },

  boost : func { return getprop(me.property) * me.boost_rate * me.injected(); },
  
  activated : func { return me.active; },

  injected : func {
    if (me.active == 1 and me.capacity > 0) {
      return 1;
    } else {
      return 0;
    }
  },

  reset : func {
    me.pump_pressure = 0.0;
    me.injection_pressure = 0.0;
    me.capacity = 12.0;
    setprop(me.property, 0.0);
    setprop(me.gauge1, 0.0);
    setprop(me.gauge2, 0.0);
  },

  consume : func {
    level = getprop(me.property);
    # injection lasts 20 mins in full-injection
    if (me.capacity > 0) {
      me.capacity -= level * 0.01;
    } else { 
      me.capacity = 0.0;
      # just to send an event to control the boost
      setprop(me.property, getprop(me.property));
    };
    interpolate("/consumables/water-methanol-injection/level-gal_us", me.capacity, 1.0);
    interpolate(me.gauge1, me.pump_pressure * me.active, 1.0);
    interpolate(me.gauge2, me.injection_pressure * me.injected(), 1.0);
    settimer(func { me.consume(); }, 1);
  },
    
  update : func {
    var level = getprop(me.property);
    if (level > 0 and getprop("/engines/engine/running") == 1) {
      me.active = 1;
      me.pump_pressure = me.min_pump_pressure + level * (me.max_pump_pressure - me.min_pump_pressure);
      if (me.capacity > 0.0) {
        me.injection_pressure = me.min_injection_pressure + level * (me.max_injection_pressure - me.min_injection_pressure);
      }
    }
    else {
      me.active = 0;
    }
  }
};

# Hydraulic Torque Converter (HTC) driven Turbine with water-methanol injection (WMI)
# 
# Instance variables
#   wmi : water-methanol injection object
Turbine = {
  new : func {
    var obj = { parents : [Turbine],
          wmi : WMInjection.new(0.5)
        };
    setprop("/controls/engines/engine/wastegate", 0.5);
    setprop("/controls/engines/engine/boost", getprop("/controls/engines/engine/raw-boost") * 0.7);
    setlistener("/controls/engines/engine/raw-boost", func { obj.setBoost(); });
    setlistener("/controls/engines/engine/water-methanol-injection", func { obj.setBoost(); });
    setlistener("/engines/engine/running", func { obj.setBoost(); });
    return obj;
  },

  setBoost : func {
    var running = getprop("/engines/engine/running");
    var boost = getprop("/controls/engines/engine/raw-boost") * running;
    setprop("/controls/engines/engine/boost", boost * 0.7 * (1 + me.wmi.boost()));
    interpolate("/instrumentation/htc/pressure-norm", getprop("/controls/engines/engine/raw-boost") * running, 1);
  },
    
  update : func {
    me.wmi.update();
    var boost = getprop("/controls/engines/engine/boost");
    var throttle = getprop("/controls/engines/engine/throttle");
    var running = getprop("/engines/engine/running");
    if (running != nil and running == 1) {
      # WASTEGATE control in YASim doesn't seem working when it's updated almost all the time in this method
      # maybe I should change the 
      setprop("/controls/engines/engine/wastegate", (1.0 + throttle) / 2);
    }
  }
};

#
# Shinden adjusts the elevator trim when flaps goes down 
# for reducing the nose-down to some extent.
# Its nose still goes down a little bit, unfortunately.
#
FlapDrivenElevatorTrim = {
  new : func {
    var obj = { parents : [FlapDrivenElevatorTrim], 
            angle_norm : 0.0,
            prev_flap_pos : 0.0,
            delay : 4,
	    is_trimming : 0,
            property : "/controls/flight/elevator-trim" };
    setlistener("/controls/flight/flaps", func { obj.adjustTrim(); });
    setlistener("/sim/signals/reinit", func { obj.reset(); });
    setprop(obj.property, 0);
    return obj;
  },

  reset : func {
    me.prev_flap_pos = 0.0;
    me.is_trimming = 0;
    setprop(me.property, 0);
    setprop("/controls/flight/flaps", 0);
  },

  adjustTrim : func {
    if (me.is_trimming == 0) {
      me.is_trimming = 1;
      var trim = getprop(me.property);
      var flap_pos = getprop("/controls/flight/flaps");
      var delta_pos = me.prev_flap_pos - flap_pos;
      me.prev_flap_pos = flap_pos;
      interpolate(me.property, trim + delta_pos / 4, me.delay);
      settimer(func { me.is_trimming = 0; }, me.delay);
    } else {
      # applying flap-down while trim is being adjusted, 
      # this function doesn't trim correctly. To avoid this issue,
      # it delays the trim for me.dealy seconds.
      settimer(func {me.adjustTrim(); }, me.delay);
    }
  }
};

var j7w = JapaneseWarbird.new();
var observers = [Altimeter.new(), BoostGauge.new(), CylinderTemperature.new(), 
                 Turbine.new(), ExhaustGasTemperature.new(41.6) ];
foreach (observer; observers) {
    j7w.addObserver(observer);
}

var elevator_trim = FlapDrivenElevatorTrim.new();

