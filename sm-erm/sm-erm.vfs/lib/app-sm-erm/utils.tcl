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

set DERIVATIVE_READINGS 5

set EXTRAPOL 100

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

proc setup {} {
    global ps tcmm log trm connectors connectorIndex connectorStep vSwitches cSwitches 

    measure::measure::setupMmsForResistance

    if { 3 != [measure::config::get current.method] && [measure::config::get ps.addr] != "" } {
        set ps [hardware::agilent::pse3645a::open \
    		-baud [measure::config::get ps.baud] \
    		-parity [measure::config::get ps.parity] \
    		-name "Power Supply" \
    		[measure::config::get -required ps.addr] \
    	]
    
        hardware::agilent::pse3645a::init $ps
    
        scpi::cmd $ps "VOLTAGE:RANGE HIGH"
        
        scpi::cmd $ps "APPLY 60.000,[expr 0.001 * [measure::config::get current.manual.current]]"
        
        hardware::agilent::pse3645a::setOutput $ps 1
    }
    
    if { 0 == [measure::config::get tc.method 0]} {
        set tcmm [hardware::agilent::mm34410a::open \
    		-baud [measure::config::get tcmm.baud] \
    		-parity [measure::config::get tcmm.parity] \
    		-name "MM3" \
    		[measure::config::get -required tcmm.addr] \
    	]
    
        hardware::agilent::mm34410a::init $tcmm
    
    	hardware::agilent::mm34410a::configureDcVoltage \
    		-nplc [measure::config::get tcmm.nplc 10] \
    		-text2 "MM3 TC" \
    		 $tcmm
    } else {
        set trm [::hardware::owen::trm201::init [measure::config::get tcm.serialAddr] [measure::config::get tcm.rs485Addr]]
    
        ::hardware::owen::trm201::setTcType $trm [measure::config::get tc.type] 
    }

    set connectors 0
    set vSwitches { 0 }
    set cSwitches { 0 }
    if { 0 != [measure::config::get switch.current 0]} {
    	lappend connectors 1000
        lappend vSwitches { 0 } 
        lappend cSwitches { 1 } 
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

proc finish {} {
    global mm cmm tcmm ps log trm

    if { [info exists mm] } {
    	hardware::agilent::mm34410a::done $mm
    	close $mm
    	unset mm
    }

    if { [info exists cmm] } {
    	hardware::agilent::mm34410a::done $cmm
    	close $cmm
    	unset cmm
    }
	
    if { [info exists ps] } {
    	hardware::agilent::pse3645a::done $ps
    	close $ps
    	unset ps
    }
    
    if { [info exists tcmm] } {
    	hardware::agilent::mm34410a::done $tcmm
    	close $tcmm
    	unset tcmm
    }
    
    if { [info exists trm] } {
        ::hardware::owen::trm201::done $trm
        unset trm
    }
    
	resetConnectors
	
	after 1000
}

proc display { v sv c sc r sr temp tempErr tempDer what disp } {
	if { [measure::interop::isAlone] } {
    	set cv [::measure::format::valueWithErr -mult 1.0e-3 $c $sc A]
    	set vv [::measure::format::valueWithErr -mult 1.0e-3 $v $sv V]
    	set rv [::measure::format::valueWithErr $r $sr "\u03A9"]
    	set pw [::measure::format::value -prec 2 [expr 1.0e-6 * $c * $v] W]
    	set tv [::measure::format::valueWithErr $temp $tempErr K]
    	puts "C=$cv\tV=$vv\tR=$rv\tP=$pw\tT=$tv"
	} else {
        measure::interop::cmd [list display $v $sv $c $sc $r $sr $temp $tempErr $tempDer $what $disp]
	}
}

set tempValues [list]
set timeValues [list]
set startTime [clock milliseconds]

proc readTemp {} {
    global tempValues timeValues startTime DERIVATIVE_READINGS log
    
    ${log}::debug "readTemp before"
    if { 0 == [measure::config::get tc.method 0]} {
        lassign [readTempMm] t tErr
    } else {
        lassign [readTempTrm] t tErr
    }
    ${log}::debug "readTemp after $t $tErr"

    measure::listutils::lappend tempValues $t $DERIVATIVE_READINGS
    measure::listutils::lappend timeValues [expr [clock milliseconds] - $startTime] $DERIVATIVE_READINGS
    if { [llength $tempValues] < $DERIVATIVE_READINGS } {
        set der 0.0
    } else {
        set der [expr 60000.0 * [measure::math::slope $timeValues $tempValues]] 
    }
            
    return [list $t $tErr $der]
}

proc readTempTrm {} {
    global trm
    return [::hardware::owen::trm201::readTemperature $trm]
}

proc readTempMm {} {
    global tcmm
    global log

    set v [string trim [scpi::query $tcmm "READ?"]]
    if { [measure::config::get tc.negate 0] } {
        set v [expr -1.0 * $v]
    }
   	set vErr [hardware::agilent::mm34410a::dcvSystematicError $v "" [measure::config::get tcmm.nplc 10]]
   	
	lassign [measure::thermocouple::calcKelvin \
        [measure::config::get tc.type K] \
        [measure::config::get tc.fixedT 77.4] \
        $v $vErr \
        [measure::config::get tc.correction] \
        ] t tErr

    return [list $t $tErr]
}

proc readResistanceAndWrite { temp tempErr tempDer { write 0 } { manual 0 } { dotrace 1 } } {
    global log
    global settings connectors connectorIndex connectorStep vSwitches cSwitches 
    global tValues tErrValues vValues vErrValues cValues cErrValues rValues rErrValues EXTRAPOL 
    global measureComments refinedMeasureComments

	lassign [measure::measure::resistance] v sv c sc r sr

    if { $write } {
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

proc setConnectors { conns } {
    global settings

    if { $settings(current.method) != 3 } {
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {1000}
    	#after 500
    
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 0 $conns
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 2 $conns
    	#after 500

        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {0}
    	#after 500
    } else {
        hardware::owen::mvu8::modbus::setChannels $settings(switch.serialAddr) $settings(switch.rs485Addr) 4 {1000}
    }
}

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
