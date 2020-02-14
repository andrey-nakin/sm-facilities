#!/usr/bin/tclsh

###############################################################################
# ERM
# Common utils
###############################################################################

package provide erm::utils 1.0.0

package require Thread
package require hardware::agilent::mm34410a
package require hardware::owen::mvu8
package require measure::thermocouple
package require measure::listutils
package require measure::math
package require hardware::agilent::pse3645a
package require hardware::owen::trm201

# \u0427\u0438\u0441\u043B\u043E \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439, \u043F\u043E \u043A\u043E\u0442\u043E\u0440\u044B\u043C \u043E\u043F\u0440\u0435\u0434\u0435\u043B\u044F\u0435\u0442\u0441\u044F \u043F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u043D\u0430\u044F dT/dt
set DERIVATIVE_READINGS 5

# \u0427\u0438\u0441\u043B\u043E \u0442\u043E\u0447\u0435\u043A, \u043F\u043E \u043A\u043E\u0442\u043E\u0440\u044B\u043C \u044D\u043A\u0441\u0442\u0440\u0430\u043F\u043E\u043B\u0438\u0440\u0443\u0435\u0442\u0441\u044F \u0438\u0437\u043C\u0435\u0440\u044F\u0435\u043C\u0430\u044F \u0432\u0435\u043B\u0438\u0447\u0438\u043D\u0430
set EXTRAPOL 100

# \u041F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u0430 \u043F\u0440\u043E\u0432\u0435\u0440\u044F\u0435\u0442 \u043F\u0440\u0430\u0432\u0438\u043B\u044C\u043D\u043E\u0441\u0442\u044C \u043D\u0430\u0441\u0442\u0440\u043E\u0435\u043A, \u043F\u0440\u0438 \u043D\u0435\u043E\u0431\u0445\u043E\u0434\u0438\u043C\u043E\u0441\u0442\u0438 \u0432\u043D\u043E\u0441\u0438\u0442 \u043F\u043E\u043F\u0440\u0430\u0432\u043A\u0438
proc validateSettings {} {
    measure::config::validate {
        result.fileName ""
        result.format TXT
        result.rewrite 1
        result.comment ""

		measure.noSystErr 0
		measure.numOfSamples 1

		current.method 0
		
		switch.voltage 0
		switch.current 0
		switch.step 1
		switch.delay 0
    }	
}

# \u0418\u043D\u0438\u0446\u0438\u0430\u043B\u0438\u0437\u0430\u0446\u0438\u044F \u043F\u0440\u0438\u0431\u043E\u0440\u043E\u0432
proc setup {} {
    global ps tcmm log trm connectors connectorIndex connectorStep vSwitches cSwitches 

    # \u0418\u043D\u0438\u0446\u0438\u0430\u043B\u0438\u0437\u0430\u0446\u0438\u044F \u043C\u0443\u043B\u044C\u0442\u0438\u043C\u0435\u0442\u0440\u043E\u0432 \u043D\u0430 \u043E\u0431\u0440\u0430\u0437\u0446\u0435
    measure::measure::setupMmsForResistance

    if { 3 != [measure::config::get current.method] && [measure::config::get ps.addr] != "" } {
        # \u0446\u0435\u043F\u044C \u0437\u0430\u043F\u0438\u0442\u044B\u0432\u0430\u0435\u0442\u0441\u044F \u043F\u0440\u0438 \u043F\u043E\u043C\u043E\u0449\u0438 \u0443\u043F\u0440\u0430\u0432\u043B\u044F\u0435\u043C\u043E\u0433\u043E \u0418\u041F
        set ps [hardware::agilent::pse3645a::open \
    		-baud [measure::config::get ps.baud] \
    		-parity [measure::config::get ps.parity] \
    		-name "Power Supply" \
    		[measure::config::get -required ps.addr] \
    	]
    
        # \u0418\u043D\u0438\u0430\u043B\u0438\u0437\u0438\u0440\u0443\u0435\u043C \u0438 \u043E\u043F\u0440\u0430\u0448\u0438\u0432\u0430\u0435\u043C \u0418\u041F
        hardware::agilent::pse3645a::init $ps
    
    	# \u0420\u0430\u0431\u043E\u0442\u0430\u0435\u043C \u0432 \u043E\u0431\u043B\u0430\u0441\u0442\u0438 \u0431\u041E\u043B\u044C\u0448\u0438\u0445 \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u0439
        scpi::cmd $ps "VOLTAGE:RANGE HIGH"
        
    	# \u0417\u0430\u0434\u0430\u0451\u043C \u043F\u0440\u0435\u0434\u0435\u043B\u044B \u043F\u043E \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u044E \u0438 \u0442\u043E\u043A\u0443
        scpi::cmd $ps "APPLY 60.000,[expr 0.001 * [measure::config::get current.manual.current]]"
        
        # \u0432\u043A\u043B\u044E\u0447\u0430\u0435\u043C \u043F\u043E\u0434\u0430\u0447\u0443 \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u044F \u043D\u0430 \u0432\u044B\u0445\u043E\u0434\u044B \u0418\u041F
        hardware::agilent::pse3645a::setOutput $ps 1
    }
    
    if { 0 == [measure::config::get tc.method 0]} {
        # \u0418\u043D\u0438\u0446\u0438\u0430\u043B\u0438\u0437\u0430\u0446\u0438\u044F \u043C\u0443\u043B\u044C\u0442\u0438\u043C\u0435\u0442\u0440\u0430 \u043D\u0430 \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u0435
        # \u041F\u043E\u0434\u043A\u043B\u044E\u0447\u0430\u0435\u043C\u0441\u044F \u043A \u043C\u0443\u043B\u044C\u0442\u0438\u043C\u0435\u0442\u0440\u0443 (\u041C\u041C)
        set tcmm [hardware::agilent::mm34410a::open \
    		-baud [measure::config::get tcmm.baud] \
    		-parity [measure::config::get tcmm.parity] \
    		-name "MM3" \
    		[measure::config::get -required tcmm.addr] \
    	]
    
        # \u0418\u043D\u0438\u0430\u043B\u0438\u0437\u0438\u0440\u0443\u0435\u043C \u0438 \u043E\u043F\u0440\u0430\u0448\u0438\u0432\u0430\u0435\u043C \u041C\u041C
        hardware::agilent::mm34410a::init $tcmm
    
    	# \u041D\u0430\u0441\u0442\u0440\u0430\u0438\u0432\u0430\u0435\u043C \u043C\u0443\u043B\u044C\u0442\u0438\u043C\u0435\u0442\u0440 \u0434\u043B\u044F \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u043F\u043E\u0441\u0442\u043E\u044F\u043D\u043D\u043E\u0433\u043E \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u044F \u043D\u0430 \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u0435
    	hardware::agilent::mm34410a::configureDcVoltage \
    		-nplc [measure::config::get tcmm.nplc 10] \
    		-text2 "MM3 TC" \
    		 $tcmm
    } else {
        set trm [::hardware::owen::trm201::init [measure::config::get tcm.serialAddr] [measure::config::get tcm.rs485Addr]]
    
        # \u041D\u0430\u0441\u0442\u0440\u0430\u0438\u0432\u0430\u0435\u043C \u0422\u0420\u041C-201 \u0434\u043B\u044F \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u044B
        ::hardware::owen::trm201::setTcType $trm [measure::config::get tc.type] 
    }

    set connectors [list { 0 0 0 0 }]
    set vSwitches { 0 }
    set cSwitches { 0 }
    if { 0 != [measure::config::get switch.voltage 0]} {
        # \u043F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043A\u0430 \u043F\u043E \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u044E
    	# \u0418\u043D\u0432\u0435\u0440\u0441\u043D\u043E\u0435 \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u0435 \u0432\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u0430
    	lappend connectors {1000 1000 0 0}
        lappend vSwitches { 1 } 
        lappend cSwitches { 0 } 
    }
    if { 0 != [measure::config::get switch.current 0]} {
        # \u043F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043A\u0430 \u043F\u043E \u0442\u043E\u043A\u0443
    	# \u0418\u043D\u0432\u0435\u0440\u0441\u043D\u043E\u0435 \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u0435 \u0438\u0441\u0442\u043E\u0447\u043D\u0438\u043A\u0430 \u0442\u043E\u043A\u0430
    	lappend connectors { 0 0 1000 1000 }
        lappend vSwitches { 0 } 
        lappend cSwitches { 1 } 
        if { 0 != [measure::config::get switch.voltage 0]} {
    		# \u0418\u043D\u0432\u0435\u0440\u0441\u043D\u043E\u0435 \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u0435 \u0432\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u0430 \u0438 \u0438\u0441\u0442\u043E\u0447\u043D\u0438\u043A\u0430 \u0442\u043E\u043A\u0430
    		lappend connectors { 1000 1000 1000 1000 } 
            lappend vSwitches { 1 } 
            lappend cSwitches { 1 } 
        }
    }
    set connectorIndex 0
    set connectorStep 0
    
    resetRefinedVars
}

proc resetRefinedVars {} {
    global tValues tErrValues vValues vErrValues cValues cErrValues rValues rErrValues
    
    set tValues {}; set tErrValues {}; set vValues {}; set vErrValues {}
    set cValues {}; set cErrValues {}; set rValues {}; set rErrValues {}
}

# \u0417\u0430\u0432\u0435\u0440\u0448\u0430\u0435\u043C \u0440\u0430\u0431\u043E\u0442\u0443 \u0443\u0441\u0442\u0430\u043D\u043E\u0432\u043A\u0438, \u043C\u0430\u0442\u0447\u0430\u0441\u0442\u044C \u0432 \u0438\u0441\u0445\u043E\u0434\u043D\u043E\u0435.
proc finish {} {
    global mm cmm tcmm ps log trm

    if { [info exists mm] } {
    	# \u041F\u0435\u0440\u0435\u0432\u043E\u0434\u0438\u043C \u0432\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440 \u0432 \u0438\u0441\u0445\u043E\u0434\u043D\u044B\u0439 \u0440\u0435\u0436\u0438\u043C
    	hardware::agilent::mm34410a::done $mm
    	close $mm
    	unset mm
    }

    if { [info exists cmm] } {
    	# \u041F\u0435\u0440\u0435\u0432\u043E\u0434\u0438\u043C \u0430\u043C\u043F\u0435\u0440\u043C\u0435\u0442\u0440 \u0432 \u0438\u0441\u0445\u043E\u0434\u043D\u044B\u0439 \u0440\u0435\u0436\u0438\u043C
    	hardware::agilent::mm34410a::done $cmm
    	close $cmm
    	unset cmm
    }
	
    if { [info exists ps] } {
    	# \u041F\u0435\u0440\u0435\u0432\u043E\u0434\u0438\u043C \u0418\u041F \u0432 \u0438\u0441\u0445\u043E\u0434\u043D\u044B\u0439 \u0440\u0435\u0436\u0438\u043C
    	hardware::agilent::pse3645a::done $ps
    	close $ps
    	unset ps
    }
    
    if { [info exists tcmm] } {
    	# \u041F\u0435\u0440\u0435\u0432\u043E\u0434\u0438\u043C \u043C\u0443\u043B\u044C\u0442\u0438\u043C\u0435\u0442\u0440 \u0432 \u0438\u0441\u0445\u043E\u0434\u043D\u044B\u0439 \u0440\u0435\u0436\u0438\u043C
    	hardware::agilent::mm34410a::done $tcmm
    	close $tcmm
    	unset tcmm
    }
    
    if { [info exists trm] } {
        # \u041F\u0435\u0440\u0435\u0432\u043E\u0434\u0438\u043C \u0422\u0420\u041C-201 \u0432 \u0438\u0441\u0445\u043E\u0434\u043D\u043E\u0435 \u0441\u043E\u0441\u0442\u043E\u044F\u043D\u0438\u0435
        ::hardware::owen::trm201::done $trm
        unset trm
    }
    
	# \u0440\u0435\u043B\u0435 \u0432 \u0438\u0441\u0445\u043E\u0434\u043D\u043E\u0435
	resetConnectors
	
	# \u0432\u044B\u0434\u0435\u0440\u0436\u0438\u043C \u043F\u0430\u0443\u0437\u0443
	after 1000
}

proc display { v sv c sc r sr temp tempErr tempDer what disp } {
	if { [measure::interop::isAlone] } {
	    # \u0412\u044B\u0432\u043E\u0434\u0438\u043C \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0432 \u043A\u043E\u043D\u0441\u043E\u043B\u044C
    	set cv [::measure::format::valueWithErr -mult 1.0e-3 $c $sc A]
    	set vv [::measure::format::valueWithErr -mult 1.0e-3 $v $sv V]
    	set rv [::measure::format::valueWithErr $r $sr "\u03A9"]
    	set pw [::measure::format::value -prec 2 [expr 1.0e-6 * $c * $v] W]
    	set tv [::measure::format::valueWithErr $temp $tempErr K]
    	puts "C=$cv\tV=$vv\tR=$rv\tP=$pw\tT=$tv"
	} else {
	    # \u0412\u044B\u0432\u043E\u0434\u0438\u043C \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0432 \u043E\u043A\u043D\u043E \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
        measure::interop::cmd [list display $v $sv $c $sc $r $sr $temp $tempErr $tempDer $what $disp]
	}
}

set tempValues [list]
set timeValues [list]
set startTime [clock milliseconds]

# \u0418\u0437\u043C\u0435\u0440\u044F\u0435\u043C \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0443 \u0438 \u0432\u043E\u0437\u0432\u0440\u0430\u0449\u0430\u0435\u043C \u0432\u043C\u0435\u0441\u0442\u0435 \u0441 \u0438\u043D\u0441\u0442\u0440\u0443\u043C\u0435\u043D\u0442\u0430\u043B\u044C\u043D\u043E\u0439 \u043F\u043E\u0433\u0440\u0435\u0448\u043D\u043E\u0441\u0442\u044C\u044E \u0438 \u043F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u043D\u043E\u0439
proc readTemp {} {
    global tempValues timeValues startTime DERIVATIVE_READINGS
    
    if { 0 == [measure::config::get tc.method 0]} {
        lassign [readTempMm] t tErr
    } else {
        lassign [readTempTrm] t tErr
    }

    # \u043D\u0430\u043A\u0430\u043F\u043B\u0438\u0432\u0430\u0435\u043C \u0437\u043D\u0430\u0447\u0435\u043D\u0438\u044F \u0432 \u043E\u0447\u0435\u0440\u0435\u0434\u0438 \u0434\u043B\u044F \u0432\u044B\u0447\u0438\u0441\u043B\u0435\u043D\u0438\u044F \u043F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u043D\u043E\u0439 
    measure::listutils::lappend tempValues $t $DERIVATIVE_READINGS
    measure::listutils::lappend timeValues [expr [clock milliseconds] - $startTime] $DERIVATIVE_READINGS
    if { [llength $tempValues] < $DERIVATIVE_READINGS } {
        set der 0.0
    } else {
        set der [expr 60000.0 * [measure::math::slope $timeValues $tempValues]] 
    }
            
    return [list $t $tErr $der]
}

# \u0421\u043D\u0438\u043C\u0430\u0435\u043C \u043F\u043E\u043A\u0430\u0437\u0430\u043D\u0438\u044F \u0432\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u0430 \u043D\u0430 \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u0435 \u0438 \u0432\u043E\u0437\u0432\u0440\u0430\u0449\u0430\u0435\u043C \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0443 
# \u0432\u043C\u0435\u0441\u0442\u0435 \u0441 \u0438\u043D\u0441\u0442\u0440\u0443\u043C\u0435\u043D\u0442\u0430\u043B\u044C\u043D\u043E\u0439 \u043F\u043E\u0433\u0440\u0435\u0448\u043D\u043E\u0441\u0442\u044C\u044E
proc readTempTrm {} {
    global trm
    return [::hardware::owen::trm201::readTemperature $trm]
}

# \u0421\u043D\u0438\u043C\u0430\u0435\u043C \u043F\u043E\u043A\u0430\u0437\u0430\u043D\u0438\u044F \u0432\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u0430 \u043D\u0430 \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u0435 \u0438 \u0432\u043E\u0437\u0432\u0440\u0430\u0449\u0430\u0435\u043C \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0443 
# \u0432\u043C\u0435\u0441\u0442\u0435 \u0441 \u0438\u043D\u0441\u0442\u0440\u0443\u043C\u0435\u043D\u0442\u0430\u043B\u044C\u043D\u043E\u0439 \u043F\u043E\u0433\u0440\u0435\u0448\u043D\u043E\u0441\u0442\u044C\u044E
proc readTempMm {} {
    global tcmm
    global log

    # \u0438\u0437\u043C\u0435\u0440\u044F\u0435\u043C \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u0435 \u043D\u0430 \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u0435    
    set v [string trim [scpi::query $tcmm "READ?"]]
    if { [measure::config::get tc.negate 0] } {
        set v [expr -1.0 * $v]
    }
	# \u0438\u043D\u0441\u0442\u0440\u0443\u043C\u0435\u043D\u0442\u0430\u043B\u044C\u043D\u0430\u044F \u043F\u043E\u0433\u0440\u0435\u0448\u043D\u043E\u0441\u0442\u044C
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" [measure::config::get tcmm.nplc 10]]
   	
   	# \u0432\u044B\u0447\u0438\u0441\u043B\u044F\u0435\u043C \u0438 \u0432\u043E\u0437\u0432\u0440\u0430\u0449\u0430\u0435\u043C \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0443 \u0441 \u0438\u043D\u0441\u0442\u0440\u0443\u043C\u0435\u043D\u0442\u0430\u043B\u044C\u043D\u043E\u0439 \u043F\u043E\u0433\u0440\u0435\u0448\u043D\u043E\u0441\u0442\u044C\u044E
	lassign [measure::thermocouple::calcKelvin \
        [measure::config::get tc.type K] \
        [measure::config::get tc.fixedT 77.4] \
        $v $vErr \
        [measure::config::get tc.correction] \
        ] t tErr

    return [list $t $tErr]
}

# \u0418\u0437\u043C\u0435\u0440\u044F\u0435\u043C \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u0435 \u0438 \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0438\u0440\u0443\u0435\u043C \u0435\u0433\u043E \u0432\u043C\u0435\u0441\u0442\u0435 \u0441 \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u043E\u0439
proc readResistanceAndWrite { temp tempErr tempDer { write 0 } { manual 0 } { dotrace 1 } } {
    global log
    global settings connectors connectorIndex connectorStep vSwitches cSwitches 
    global tValues tErrValues vValues vErrValues cValues cErrValues rValues rErrValues EXTRAPOL 
    global measureComments refinedMeasureComments

	# \u0418\u0437\u043C\u0435\u0440\u044F\u0435\u043C \u043D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u0435
	lassign [measure::measure::resistance] v sv c sc r sr

    if { $write } {
    	# \u0412\u044B\u0432\u043E\u0434\u0438\u043C \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0432 \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0438\u0440\u0443\u044E\u0449\u0438\u0439 \u0444\u0430\u0439\u043B
    	writeDataPoint $settings(result.fileName) $temp $tempErr $tempDer \
            $v $sv $c $sc $r $sr    \
            $manual [lindex $vSwitches $connectorIndex] [lindex $cSwitches $connectorIndex] \
            measureComments   
    }
    
    if { $dotrace } {
    	measure::datafile::write [measure::config::get trace.fileName] [list \
            TIMESTAMP \
            [format %0.3f $temp] [format %0.3f $tempDer] [format %0.6g $r]  \
        ]
    }
    
    if { $write } {
        ::measure::listutils::lappend tValues $temp $EXTRAPOL
        ::measure::listutils::lappend tErrValues $tempErr $EXTRAPOL
        ::measure::listutils::lappend vValues $v $EXTRAPOL
        ::measure::listutils::lappend vErrValues $sv $EXTRAPOL
        ::measure::listutils::lappend cValues $c $EXTRAPOL
        ::measure::listutils::lappend cErrValues $sc $EXTRAPOL
        ::measure::listutils::lappend rValues $r $EXTRAPOL
        ::measure::listutils::lappend rErrValues $sr $EXTRAPOL
    }

    if ($write) {    
        if { [llength $connectors] > 1} {
            display $v $sv $c $sc $r $sr $temp $tempErr $tempDer result 1
             
            incr connectorStep
            
            if { [measure::config::get switch.step 1] <= $connectorStep } {
                set connectorStep 0
                incr connectorIndex
                if { $connectorIndex >= [llength $connectors] } {
                	lassign [refineDataPoint $tValues $tErrValues $vValues $vErrValues] refinedT refinedTErr refinedV refinedVErr 
                	lassign [refineDataPoint $tValues $tErrValues $cValues $cErrValues] refinedT refinedTErr refinedC refinedCErr 
                	lassign [refineDataPoint $tValues $tErrValues $rValues $rErrValues] refinedT refinedRErr refinedR refinedRErr 
                     
                    display $refinedV $refinedVErr $refinedC $refinedCErr $refinedR $refinedRErr $refinedT $refinedTErr $tempDer refined 0
                    
                	writeDataPoint [refinedFileName $settings(result.fileName)] $refinedT $refinedTErr $tempDer \
                        $refinedV $refinedVErr $refinedC $refinedCErr $refinedR $refinedRErr \
                        0 "" "" refinedMeasureComments   
        
                    resetRefinedVars
                    set connectorIndex 0 
                }
                setConnectors [lindex $connectors $connectorIndex]
                after [measure::config::get switch.delay 0]
            }
        } else {
            display $v $sv $c $sc $r $sr $temp $tempErr $tempDer refined 1
        }
    } else {
        display $v $sv $c $sc $r $sr $temp $tempErr $tempDer test 1
    }
}

proc resetConnectors { } {
    global settings

    hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 0 {0 0 0 0 0 0 0 0}
}

# \u0423\u0441\u0442\u0430\u043D\u0430\u0432\u043B\u0438\u0432\u0430\u0435\u0442 \u043F\u043E\u043B\u043E\u0436\u0435\u043D\u0438\u0435 \u043F\u0435\u0440\u0435\u043A\u043B\u044E\u0447\u0430\u0442\u0435\u043B\u0435\u0439 \u043F\u043E\u043B\u044F\u0440\u043D\u043E\u0441\u0442\u0438
proc setConnectors { conns } {
    global settings

    if { $settings(current.method) != 3 } {
    	# \u0440\u0430\u0437\u043C\u044B\u043A\u0430\u0435\u043C \u0446\u0435\u043F\u044C
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {1000}
    	#after 500
    
    	# \u043F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u0438\u043C \u043F\u0435\u0440\u0435\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u0435 \u043F\u043E\u043B\u044F\u0440\u043D\u043E\u0441\u0442\u0438
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 0 $conns
    	#after 500

    	# \u0437\u0430\u043C\u044B\u043A\u0430\u0435\u043C \u0446\u0435\u043F\u044C
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {0}
    	#after 500
    } else {
    	# \u0432 \u0434\u0430\u043D\u043D\u043E\u043C \u0440\u0435\u0436\u0438\u043C\u0435 \u0446\u0435\u043F\u044C \u0432\u0441\u0435\u0433\u0434\u0430 \u0440\u0430\u0437\u043E\u043C\u043A\u043D\u0443\u0442\u0430
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {1000}
    }
}

# \u043A\u043E\u043D\u0441\u0442\u0440\u0443\u0438\u0440\u0443\u0435\u0442 \u0438\u043C\u044F \u0444\u0430\u0439\u043B\u0430 \u0434\u043B\u044F \u043E\u0447\u0438\u0449\u0435\u043D\u043D\u044B\u0445 \u0434\u0430\u043D\u043D\u044B\u0445
proc refinedFileName { fn } {
    return "[file rootname $fn].refined[file extension $fn]"
}

proc refineDataPoint { tValues tErrValues values errValues } {
    global log MIN_R2
    set len [llength $values]

    # special case #1    
    if { $len == 0 } {
        return {0 0 0 0}
    }

    # special case #2
    if { $len == 1 } {
        return [list [lindex $tValues 0] [lindex $tErrValues 0] [lindex $values 0] [lindex $errValues 0] ]
    }

    lassign [::math::statistics::basic-stats $tValues] tMean _ _ _ tStd
    lassign [::math::statistics::basic-stats $values] mean _ _ _ std
    # average errors
    set tAvgErr [::math::statistics::mean $tErrValues]
    set avgErr [::math::statistics::mean $errValues]
    # cumulative errors
    set tCumErr [::measure::sigma::add $tAvgErr $tStd]
    set cumErr [::measure::sigma::add $avgErr $std]
    return [list $tMean $tCumErr $mean $cumErr ]
}

# \u0437\u0430\u043F\u0438\u0441\u044B\u0432\u0430\u0435\u0442 \u0442\u043E\u0447\u043A\u0443 \u0432 \u0444\u0430\u0439\u043B \u0434\u0430\u043D\u043D\u044B\u0445 \u0441 \u043F\u043E\u043F\u0443\u0442\u043D\u044B\u043C \u0432\u044B\u0447\u0438\u0441\u043B\u0435\u043D\u0438\u0435\u043C \u0443\u0434\u0435\u043B\u044C\u043D\u043E\u0433\u043E \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u044F
proc writeDataPoint { fn temp tempErr tempDer v sv c sc r sr { manual 0 } { vPolarity "" } { cPolarity "" } { cfn "" } } {
    global $cfn

	lassign [::measure::measure::calcRho $r $sr] rho rhoErr
    if { $rho != "" } {
        set rho [format %0.6g $rho]
        set rhoErr [format %0.2g $rhoErr]
    }
	
	if { $manual } {
	   set manual true
    } else {
        set manual ""
    }
    
    set comment ""
    if { [string length $cfn] > 0 && [info exists $cfn] } {
        upvar 0 $cfn cmt
        set comment $cmt
        unset $cfn 
    }
 
    if { [tsv::exists measure suspendWrite] && [tsv::get measure suspendWrite] != 0 } {
		# write operation is suspended by user
        return
    }
   
	measure::datafile::write $fn [list \
        TIMESTAMP [format %0.3f $temp] [format %0.3f $tempErr] [format %0.3f $tempDer]  \
        [format %#.6g $c] [format %#.2g $sc]    \
        [format %#.6g $v] [format %#.2g $sv]    \
        [format %#.6g $r] [format %#.2g $sr]    \
        $rho $rhoErr  \
        $manual $vPolarity $cPolarity \
        $comment ]
}
