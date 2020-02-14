#!/usr/bin/tclsh

###############################################################################
# ERM
# Measurement module
###############################################################################

package provide erm::measure 1.0.0

package require math::statistics
package require http 2.7
package require measure::logger
package require measure::config
package require measure::datafile
package require measure::interop
package require measure::ranges
package require measure::measure
package require measure::listutils
package require scpi

###############################################################################
# \u041A\u043E\u043D\u0441\u0442\u0430\u043D\u0442\u044B
###############################################################################

###############################################################################
# Entry point
###############################################################################

package require erm::utils
                   
# \u041F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u0438\u0442 \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u044E \u0434\u0430\u043D\u043D\u044B\u0445 \u043F\u043E \u0437\u0430\u0434\u0430\u043D\u043D\u043E\u043C\u0443 \u0432\u0440\u0435\u043C\u0435\u043D\u043D\u043E\u043C\u0443 \u0448\u0430\u0433\u0443
proc runTimeStep {} {
    global doMeasurement
    
    set step [measure::config::get prog.time.step 1000.0]
    
    # \u0412\u044B\u043F\u043E\u043B\u043D\u044F\u0435\u043C \u0446\u0438\u043A\u043B \u043F\u043E\u043A\u0430 \u043D\u0435 \u043F\u0440\u0435\u0440\u0432\u0451\u0442 \u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u0442\u0435\u043B\u044C
    while { ![measure::interop::isTerminated] } {
        set t1 [clock milliseconds]
        
        # \u0441\u0447\u0438\u0442\u044B\u0432\u0430\u0435\u043C \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0443
        lassign [readTemp] temp tempErr tempDer
        
        # \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0438\u0440\u0443\u0435\u043C \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u0435
        readResistanceAndWrite $temp $tempErr $tempDer 1 $doMeasurement
        
        set t2 [clock milliseconds]
        after [expr int($step - ($t2 - $t1))] set doMeasurement 0
        vwait doMeasurement
        after cancel set doMeasurement 0
    }
}

# \u041F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u0438\u0442 \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u044E \u0434\u0430\u043D\u043D\u044B\u0445 \u043F\u043E \u0437\u0430\u0434\u0430\u043D\u043D\u043E\u043C\u0443 \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u043D\u043E\u043C\u0443 \u0448\u0430\u0433\u0443
set tempDerValues {}

proc runTempStep {} {
    global doMeasurement tempDerValues scpi::commandDelays tcmm
    global log
    
    if { [info exists tcmm] } {
        set scpi::commandDelays($tcmm) 0.0
    }
    
    set step [measure::config::get prog.temp.step 1.0]
    lassign [readTemp] temp tempErr
    set prevN [expr floor($temp / $step + 0.5)]
    set prevT [expr $prevN * $step]
    
    # \u0412\u044B\u043F\u043E\u043B\u043D\u044F\u0435\u043C \u0446\u0438\u043A\u043B \u043F\u043E\u043A\u0430 \u043D\u0435 \u043F\u0440\u0435\u0440\u0432\u0451\u0442 \u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u0442\u0435\u043B\u044C
    while { ![measure::interop::isTerminated] } {
        # \u0442\u0435\u043A\u0443\u0449\u0435\u0435 \u0432\u0440\u0435\u043C\u044F
        set t [clock milliseconds]
    
        # \u0441\u0447\u0438\u0442\u044B\u0432\u0430\u0435\u043C \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0443
        lassign [readTemp] temp tempErr tempDer
        measure::listutils::lappend tempDerValues $tempDer 10 
        
        if { $doMeasurement
            || $temp > $prevT && $temp > [expr ($prevN + 1) * $step]  \
            || $temp < $prevT && $temp < [expr ($prevN - 1) * $step] } {

            # \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0438\u0440\u0443\u0435\u043C \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u0435
            readResistanceAndWrite $temp $tempErr $tempDer 1 $doMeasurement
            
            set prevT [expr floor($temp / $step + 0.5) * $step]
            set prevN [expr floor($temp / $step + 0.5)]
        } else {
            # \u0438\u0437\u043C\u0435\u0440\u044F\u0435\u043C \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u0435, \u043D\u043E \u043D\u0435 \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0438\u0440\u0443\u0435\u043C
            readResistanceAndWrite $temp $tempErr $tempDer 0
        } 

        # \u043E\u043F\u0440\u0435\u0434\u0435\u043B\u0438\u043C, \u043A\u0430\u043A\u0443\u044E \u043F\u0430\u0443\u0437\u0443 \u043D\u0443\u0436\u043D\u043E \u0432\u044B\u0434\u0435\u0440\u0436\u0430\u0442\u044C \u0432 \u0437\u0430\u0432\u0438\u0441\u0438\u043C\u043E\u0441\u0442\u0438 \u043E\u0442 dT/dt
        set der [math::statistics::mean $tempDerValues]
        set delay [expr 0.05 * $step / (abs($der) / 60000.0)]
        set delay [expr min($delay, 1000)]
        set delay [expr int($delay - ([clock milliseconds] - $t))]
        if { $delay > 50 } {
            after $delay set doMeasurement 0
            vwait doMeasurement
            after cancel set doMeasurement 0
        }
    }
}

# \u041F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u0438\u0442 \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u044E \u0434\u0430\u043D\u043D\u044B\u0445 \u043F\u043E \u043A\u043E\u043C\u0430\u043D\u0434\u0430\u043C \u043E\u043F\u0435\u0440\u0430\u0442\u043E\u0440\u0430
proc runManual {} {
    global doMeasurement
    global connectors connectorIndex connectorStep

    # \u0412\u044B\u043F\u043E\u043B\u043D\u044F\u0435\u043C \u0446\u0438\u043A\u043B \u043F\u043E\u043A\u0430 \u043D\u0435 \u043F\u0440\u0435\u0440\u0432\u0451\u0442 \u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u0442\u0435\u043B\u044C
    while { ![measure::interop::isTerminated] } {
        set connectorStep 0
        set connectorIndex 0
        set n [expr { int([llength $connectors] * [measure::config::get switch.step 1]) }]
        
        for { set i 0 } { $i < $n && ![measure::interop::isTerminated] } { incr i } {
            # \u0441\u0447\u0438\u0442\u044B\u0432\u0430\u0435\u043C \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0443
            lassign [readTemp] temp tempErr tempDer
            
            # \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0438\u0440\u0443\u0435\u043C \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u0435
            readResistanceAndWrite $temp $tempErr $tempDer $doMeasurement $doMeasurement
        } 
        
        after 500 set doMeasurement 0
        vwait doMeasurement
        after cancel set doMeasurement 0
    }
}

###############################################################################
# \u041E\u0431\u0440\u0430\u0431\u043E\u0442\u0447\u0438\u043A\u0438 \u0441\u043E\u0431\u044B\u0442\u0438\u0439
###############################################################################

# \u041A\u043E\u043C\u0430\u043D\u0434\u0430 \u043F\u0440\u043E\u0447\u0438\u0442\u0430\u0442\u044C \u043F\u043E\u0441\u043B\u0435\u0434\u043D\u0438\u0435 \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438
proc applySettings { lst } {
	global settings

	array set settings $lst
}

# \u041F\u0440\u043E\u0438\u0437\u0432\u0435\u0441\u0442\u0438 \u043E\u0447\u0435\u0440\u0435\u0434\u043D\u043E\u0435 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0435
proc makeMeasurement {} {
    global doMeasurement
    
    set doMeasurement 1
}

proc addComment { comment } {
    global log measureComments refinedMeasureComments

    if { ![info exists measureComments] } {
        set measureComments {}
    }
    if { ![info exists refinedMeasureComments] } {
        set refinedMeasureComments {}
    }
    lappend measureComments "$comment"
    lappend refinedMeasureComments "$comment"
}

###############################################################################
# \u041D\u0430\u0447\u0430\u043B\u043E \u0440\u0430\u0431\u043E\u0442\u044B
###############################################################################

# \u0418\u043D\u0438\u0446\u0438\u0430\u043B\u0438\u0437\u0438\u0440\u0443\u0435\u043C \u043F\u0440\u043E\u0442\u043E\u043A\u043E\u043B\u0438\u0440\u043E\u0432\u0430\u043D\u0438\u0435
set log [measure::logger::init measure]

# \u042D\u0442\u0430 \u043A\u043E\u043C\u0430\u043D\u0434\u0430 \u0431\u0443\u0434\u0435\u0442 \u0432\u044B\u0437\u0432\u0430\u0430\u0442\u044C\u0441\u044F \u0432 \u0441\u043B\u0443\u0447\u0430\u0435 \u043F\u0440\u0435\u0436\u0434\u0435\u0432\u0440\u0435\u043C\u0435\u043D\u043D\u043E\u0439 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u043A\u0438 \u043F\u043E\u0442\u043E\u043A\u0430
measure::interop::registerFinalization { finish }

# \u0427\u0438\u0442\u0430\u0435\u043C \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
measure::config::read

# \u041F\u0440\u043E\u0432\u0435\u0440\u044F\u0435\u043C \u043F\u0440\u0430\u0432\u0438\u043B\u044C\u043D\u043E\u0441\u0442\u044C \u043D\u0430\u0441\u0442\u0440\u043E\u0435\u043A
validateSettings

# \u041F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u0438\u043C \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u0435 \u043A \u0443\u0441\u0442\u0440\u043E\u0439\u0441\u0442\u0432\u0430\u043C \u0438 \u0438\u0445 \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0443
setup

# \u0421\u043E\u0437\u0434\u0430\u0451\u043C \u0444\u0430\u0439\u043B\u044B \u0441 \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u0430\u043C\u0438 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439
measure::datafile::create $settings(result.fileName) $settings(result.format) $settings(result.rewrite) {
	"Date/Time" "T (K)" "+/- (K)" "dT/dt (K/min)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)" "Rho (Ohm*cm)" "+/- (Ohm*cm)" "Manual" "U polarity" "I polarity" 
} "$settings(result.comment), [measure::measure::dutParams]"

if { $settings(switch.voltage) || $settings(switch.current) } {
    # \u0432 \u0441\u043B\u0443\u0447\u0430\u0435 \u043F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043E\u043A \u0441\u043E\u0437\u0434\u0430\u0434\u0438\u043C \u0435\u0449\u0451 \u043E\u0434\u0438\u043D \u0444\u0430\u0439\u043B \u0441 "\u043E\u0447\u0438\u0449\u0435\u043D\u043D\u044B\u043C\u0438" \u0434\u0430\u043D\u043D\u044B\u043C\u0438
    measure::datafile::create [refinedFileName $settings(result.fileName)] $settings(result.format) $settings(result.rewrite) {
    	"Date/Time" "T (K)" "+/- (K)" "dT/dt (K/min)" "I (mA)" "+/- (mA)" "U (mV)" "+/- (mV)" "R (Ohm)" "+/- (Ohm)" "Rho (Ohm*cm)" "+/- (Ohm*cm)" 
    } "$settings(result.comment), [measure::measure::dutParams]"
}

measure::datafile::create [measure::config::get trace.fileName] [measure::config::get result.format] [measure::config::get result.rewrite] {
	"Date/Time" "T (K)" "dT/dt (K/min)" "R (Ohm)" 
} "$settings(result.comment), [measure::measure::dutParams]"

###############################################################################
# \u041E\u0441\u043D\u043E\u0432\u043D\u043E\u0439 \u0446\u0438\u043A\u043B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439
###############################################################################

# \u0425\u043E\u043B\u043E\u0441\u0442\u043E\u0435 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0435 \u0434\u043B\u044F "\u043F\u0440\u043E\u0433\u0440\u0435\u0432\u0430" \u043C\u0443\u043B\u044C\u0442\u0438\u043C\u0435\u0442\u0440\u043E\u0432
measure::measure::resistance -n 1
readTemp

set doMeasurement 0
if { $settings(prog.method) == 0 } {
    runTimeStep
} elseif { $settings(prog.method) == 1 } {
    runTempStep
} else {
    runManual
}

###############################################################################
# \u0417\u0430\u0432\u0435\u0440\u0448\u0435\u043D\u0438\u0435 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439
###############################################################################

finish

