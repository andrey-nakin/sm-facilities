#!/usr/bin/wish

###############################################################################
# ERM
# Main module
###############################################################################

package provide app-sm-erm 0.1.8

package require Tcl 8.5
package require Tk 8.5
package require Ttk 8.5
package require Plotchart
package require Thread
package require inifile
package require math::statistics
package require measure::widget
package require measure::widget::images
package require measure::logger
package require measure::config
package require measure::visa
package require measure::com
package require measure::interop
package require measure::chart
package require measure::datafile
package require measure::format
package require startfile
package require hardware::agilent::mm34410a
package require measure::widget::fullscreen

###############################################################################
# \u041A\u043E\u043D\u0441\u0442\u0430\u043D\u0442\u044B
###############################################################################

###############################################################################
# \u041F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u044B
###############################################################################

# \u041E\u0447\u0438\u0449\u0430\u0435\u043C \u043F\u043E\u043B\u044F \u0441 \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u0430\u043C\u0438 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439
proc clearResults {} {
    global runtime chartR_T chartR_t chartT_t chartdT_t

	set runtime(current) ""
	set runtime(voltage) ""
	set runtime(resistance) ""
	set runtime(power) ""

	measure::chart::${chartR_t}::clear
	measure::chart::${chartT_t}::clear
	measure::chart::${chartdT_t}::clear
   	measure::chart::${chartR_T}::clear
}

# \u0417\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u0442\u0435\u0441\u0442\u043E\u0432\u044B\u0439 \u043C\u043E\u0434\u0443\u043B\u044C
proc startTester {} {
	# \u0421\u043E\u0445\u0440\u0430\u043D\u044F\u0435\u043C \u043F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
	measure::config::write

    # \u041E\u0447\u0438\u0449\u0430\u0435\u043C \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0432 \u043E\u043A\u043D\u0435 \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
	clearResults

    # \u0421\u0431\u0440\u0430\u0441\u044B\u0432\u0430\u0435\u043C \u0441\u0438\u0433\u043D\u0430\u043B "\u043F\u0440\u0435\u0440\u0432\u0430\u043D"
    measure::interop::clearTerminated

	# \u0417\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u043D\u0430 \u0432\u044B\u043F\u043E\u043B\u043D\u0435\u043D\u0438\u0435 \u0444\u043E\u043D\u043E\u0432\u044B\u0439 \u043F\u043E\u0442\u043E\u043A	\u0441 \u043F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u043E\u0439 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F
	measure::interop::startWorker { package require erm::tester } {} {}
}

# \u041F\u0440\u0435\u0440\u044B\u0432\u0430\u0435\u043C \u0440\u0430\u0431\u043E\u0442\u0443 \u0442\u0435\u0441\u0442\u043E\u0432\u043E\u0433\u043E \u043C\u043E\u0434\u0443\u043B\u044F
proc terminateTester {} {
	# \u041F\u043E\u0441\u044B\u043B\u0430\u0435\u043C \u0432 \u0438\u0437\u043C\u0435\u0440\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0439 \u043F\u043E\u0442\u043E\u043A \u0441\u0438\u0433\u043D\u0430\u043B \u043E\u0431 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u0435
	measure::interop::waitForWorkerThreads
}

proc setSuspendWrite { suspend } {
	tsv::set measure suspendWrite $suspend
}

# \u041F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u0430 \u0432\u044B\u0437\u044B\u0432\u0430\u0435\u0438\u0441\u044F \u0438\u0437 \u0444\u043E\u043D\u043E\u0432\u043E\u0433\u043E \u0440\u0430\u0431\u043E\u0447\u0435\u0433\u043E \u043F\u043E\u0442\u043E\u043A\u0430 \u043F\u043E \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043D\u0438\u0438 \u0435\u0433\u043E \u0440\u0430\u0431\u043E\u0442\u044B
proc stopMeasure {} {
	global w log workerId

	unset workerId

	# \u0417\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u0442\u0435\u0441\u0442\u0435\u0440
	startTester

	# \u0440\u0430\u0437\u0440\u0435\u0448\u0430\u0435\u043C \u043A\u043D\u043E\u043F\u043A\u0443 \u0437\u0430\u043F\u0443\u0441\u043A\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439
	$w.nb.m.ctl.start configure -state normal
     
    # \u0417\u0430\u043F\u0440\u0435\u0449\u0430\u0435\u043C \u043A\u043D\u043E\u043F\u043A\u0443 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439    
	$w.nb.m.ctl.stop configure -state disabled
	$w.nb.m.ctl.measure configure -state disabled
	$w.nb.m.ctl.suspend configure -state disabled
	$w.nb.m.ctl.suspend state !selected
	$w.nb.m.ctl.addComment configure -state disabled
}

# \u0417\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F
proc startMeasure {} {
	global w log runtime chartR_T workerId

	# \u0437\u0430\u043F\u0440\u0435\u0449\u0430\u0435\u043C \u043A\u043D\u043E\u043F\u043A\u0443 \u0437\u0430\u043F\u0443\u0441\u043A\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439
	$w.nb.m.ctl.start configure -state disabled

	# \u041E\u0441\u0442\u0430\u043D\u0430\u0432\u043B\u0438\u0432\u0430\u0435\u043C \u0440\u0430\u0431\u043E\u0442\u0443 \u0442\u0435\u0441\u0442\u0435\u0440\u0430
	terminateTester

	# \u0421\u043E\u0445\u0440\u0430\u043D\u044F\u0435\u043C \u043F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
	measure::config::write

    # \u0421\u0431\u0440\u0430\u0441\u044B\u0432\u0430\u0435\u043C \u0441\u0438\u0433\u043D\u0430\u043B "\u043F\u0440\u0435\u0440\u0432\u0430\u043D"
    measure::interop::clearTerminated

	# clear "suspend write" status
	setSuspendWrite 0
    
	# \u0417\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u043D\u0430 \u0432\u044B\u043F\u043E\u043B\u043D\u0435\u043D\u0438\u0435 \u0444\u043E\u043D\u043E\u0432\u044B\u0439 \u043F\u043E\u0442\u043E\u043A	\u0441 \u043F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u043E\u0439 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F
	set workerId [measure::interop::startWorker { package require erm::measure } { stopMeasure } ]

    # \u0420\u0430\u0437\u0440\u0435\u0448\u0430\u0435\u043C \u043A\u043D\u043E\u043F\u043A\u0443 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439
	$w.nb.m.ctl.stop configure -state normal
	$w.nb.m.ctl.measure configure -state normal
	$w.nb.m.ctl.suspend configure -state normal
	$w.nb.m.ctl.suspend state !selected
	$w.nb.m.ctl.addComment configure -state normal
	
    # \u041E\u0447\u0438\u0449\u0430\u0435\u043C \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0432 \u043E\u043A\u043D\u0435 \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
	clearResults

	# \u041E\u0447\u0438\u0449\u0430\u0435\u043C \u0433\u0440\u0430\u0444\u0438\u043A
	measure::chart::${chartR_T}::clear
}

# \u041F\u0440\u0435\u0440\u044B\u0432\u0430\u0435\u043C \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F
proc terminateMeasure {} {
    global w log

    # \u0417\u0430\u043F\u0440\u0435\u0449\u0430\u0435\u043C \u043A\u043D\u043E\u043F\u043A\u0443 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0439    
	$w.nb.m.ctl.stop configure -state disabled
	$w.nb.m.ctl.measure configure -state disabled
	$w.nb.m.ctl.suspend configure -state disabled
	$w.nb.m.ctl.suspend state !selected
	$w.nb.m.ctl.addComment configure -state disabled
	
	# \u041F\u043E\u0441\u044B\u043B\u0430\u0435\u043C \u0432 \u0438\u0437\u043C\u0435\u0440\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0439 \u043F\u043E\u0442\u043E\u043A \u0441\u0438\u0433\u043D\u0430\u043B \u043E\u0431 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u0435
	measure::interop::terminate
}

# \u041E\u0442\u043A\u0440\u044B\u0432\u0430\u0435\u043C \u0444\u0430\u0439\u043B \u0441 \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u043C\u0438 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F
proc openResults {} {
    global settings

	if { [info exists settings(result.fileName)] } {
	    set fn [::measure::datafile::parseFileName $settings(result.fileName)]
	    if { [file exists $fn] } {
    	    startfile::start $fn
        }
	}
}

# \u0417\u0430\u0432\u0435\u0440\u0448\u0435\u043D\u0438\u0435 \u0440\u0430\u0431\u043E\u0442\u044B \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
proc quit {} {
	# \u0421\u043E\u0445\u0440\u0430\u043D\u044F\u0435\u043C \u043F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
	::measure::config::write

	# \u0437\u0430\u0432\u0435\u0440\u0448\u0430\u0435\u043C \u0438\u0437\u043C\u0435\u0440\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0439 \u043F\u043E\u0442\u043E\u043A, \u0435\u0441\u043B\u0438 \u043E\u043D \u0437\u0430\u043F\u0443\u0449\u0435\u043D
	::measure::interop::waitForWorkerThreads

    # \u043E\u0441\u0442\u0430\u043D\u0430\u0432\u043B\u0438\u0432\u0430\u0435\u043C \u043F\u043E\u0442\u043E\u043A \u0437\u0430\u043F\u0438\u0441\u0438 \u0434\u0430\u043D\u043D\u044B\u0445
    ::measure::datafile::shutdown
     
    # \u043E\u0441\u0442\u0430\u043D\u0430\u0432\u043B\u0438\u0432\u0430\u0435\u043C \u043F\u043E\u0442\u043E\u043A \u043F\u0440\u043E\u0442\u043E\u043A\u043E\u043B\u0438\u0440\u043E\u0432\u0430\u043D\u0438\u044F
	::measure::logger::shutdown

	exit
}

# \u041F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u0430 \u0440\u0430\u0437\u0440\u0435\u0448\u0430\u0435\u0442/\u0437\u0430\u043F\u0440\u0435\u0449\u0430\u0435\u0442 \u044D\u043B\u0435\u043C\u0435\u043D\u0442\u044B \u0432\u0432\u043E\u0434\u0430 \u044D\u0442\u0430\u043B\u043E\u043D\u043D\u043E\u0433\u043E \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u044F
proc toggleTestResistance {} {
	global w
	set p "$w.nb.ms.r.curr"
	set mode [measure::config::get current.method 0]
# TODO	::measure::widget::setDisabled [expr $mode == 1] $p.r $p.lr
# TODO	::measure::widget::setDisabled [expr $mode == 1] $p.rerr $p.lrerr
	::measure::widget::setDisabled [expr $mode != 3] $p.cur $p.lcur
	::measure::widget::setDisabled [expr $mode == 2] $p.curerr $p.lcurerr
}

# \u041F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u0430 \u0440\u0430\u0437\u0440\u0435\u0448\u0430\u0435\u0442/\u0437\u0430\u043F\u0440\u0435\u0449\u0430\u0435\u0442 \u044D\u043B\u0435\u043C\u0435\u043D\u0442\u044B \u0432\u0432\u043E\u0434\u0430 \u044D\u0442\u0430\u043B\u043E\u043D\u043D\u043E\u0433\u043E \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u044F
proc toggleProgControls {} {
	global w
	set p "$w.nb.ms.l.prog"
	set mode [measure::config::get prog.method 0]
	::measure::widget::setDisabled [expr $mode == 0] $p.timeStep
	::measure::widget::setDisabled [expr $mode == 1] $p.tempStep
}

# \u041F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u0430 \u0440\u0430\u0437\u0440\u0435\u0448\u0430\u0435\u0442/\u0437\u0430\u043F\u0440\u0435\u0449\u0430\u0435\u0442 \u044D\u043B\u0435\u043C\u0435\u043D\u0442\u044B \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u044B
proc toggleTcMethodControls {} {
	global w
	set p "$w.nb.tsetup"
	set mode [measure::config::get tc.method 0]
	::measure::widget::setDisabled [expr $mode == 0] $p.tcmm
	::measure::widget::setDisabled [expr $mode == 0] $p.tc.fixedT
	::measure::widget::setDisabled [expr $mode == 0] $p.tc.lfixedT
	::measure::widget::setDisabled [expr $mode == 0] $p.tc.negate
	::measure::widget::setDisabled [expr $mode == 0] $p.tc.lnegate
	::measure::widget::setDisabled [expr $mode == 1] $p.tcm
}

proc makeMeasurement {} {
	global workerId

	if { [info exists workerId] } {
		thread::send -async $workerId makeMeasurement
	}
}

proc addComment {} {
    global measureComment 
	global workerId
	if { [info exists workerId] } {
		thread::send -async $workerId "addComment \"$measureComment\""
	}
}

proc toggleSuspend {} {
	global w
	set s 0
	$w.nb.m.ctl.suspend instate selected { set s 1 }
    setSuspendWrite $s
}

###############################################################################
# \u041E\u0431\u0440\u0430\u0431\u043E\u0442\u0447\u0438\u043A\u0438 \u0441\u043E\u0431\u044B\u0442\u0438\u0439
###############################################################################

proc display { v sv c sc r sr temp tempErr tempDer what disp } {
    global runtime chartR_T chartR_t chartT_t chartdT_t w
    
    if { $disp } {
        # \u0412\u044B\u0432\u043E\u0434\u0438\u043C \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0432 \u043E\u043A\u043D\u043E \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
    	set runtime(temperature) [::measure::format::valueWithErr -- $temp $tempErr "\u041A"]
    	set runtime(derivative1) [::measure::format::value -prec 3 -- $tempDer "\u041A/\u043C\u0438\u043D"]
    	set runtime(current) [::measure::format::valueWithErr -mult 1.0e-3 -- $c $sc "\u0410"]
    	set runtime(voltage) [::measure::format::valueWithErr -mult 1.0e-3 -- $v $sv "\u0412"]
    	set runtime(resistance) [::measure::format::valueWithErr -- $r $sr "\u03A9"]
    	set runtime(power) [::measure::format::value -prec 2 -- [expr 1.0e-6 * $c * $v] "\u0412\u0442"]
    
    	measure::chart::${chartR_t}::setYErr $sr
    	measure::chart::${chartR_t}::addPoint $r
        measure::chart::${chartT_t}::addPoint $temp
    	measure::chart::${chartdT_t}::addPoint $tempDer

    	event generate ${w}. <<ReadTemperature>> -data $temp
    }
    
   	measure::chart::${chartR_T}::addPoint $temp $r $what
}

###############################################################################
# \u041D\u0430\u0447\u0430\u043B\u043E \u0441\u043A\u0440\u0438\u043F\u0442\u0430
###############################################################################

set log [measure::logger::init measure]
# \u0437\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u0432\u044B\u0434\u0435\u043B\u0435\u043D\u043D\u044B\u0439 \u043F\u043E\u0442\u043E\u043A \u043F\u0440\u043E\u0442\u043E\u043A\u043E\u043B\u0438\u0440\u043E\u0432\u0430\u043D\u0438\u044F
::measure::logger::server

# \u0437\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u0432\u044B\u0434\u0435\u043B\u0435\u043D\u043D\u044B\u0439 \u043F\u043E\u0442\u043E\u043A \u0437\u0430\u043F\u0438\u0441\u0438 \u0434\u0430\u043D\u043D\u044B\u0445
::measure::datafile::startup

# \u0421\u043E\u0437\u0434\u0430\u0451\u043C \u043E\u043A\u043D\u043E \u043F\u0440\u043E\u0433\u0440\u0430\u043C\u043C\u044B
set w ""
wm title $w. "\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u044F R(T). \u0412\u0435\u0440\u0441\u0438\u044F [package versions app-sm-erm]"

# \u041F\u0440\u0438 \u043D\u0430\u0436\u0430\u0442\u0438\u0438 \u043A\u0440\u0435\u0441\u0442\u0438\u043A\u0430 \u0432 \u0443\u0433\u043B\u0443 \u043E\u043A\u043D\u0430 \u0432\u044B\u0437\u044B\u0432\u0430\u0442\u044C\u0441\u043F\u0435\u0446\u0438\u0430\u043B\u044C\u043D\u0443\u044E \u043F\u0440\u043E\u0446\u0435\u0434\u0443\u0440\u0443 \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043D\u0438\u044F
wm protocol $w. WM_DELETE_WINDOW { quit }

# \u0412\u0438\u0440\u0442\u0443\u0430\u043B\u044C\u043D\u043E\u0435 \u0441\u043E\u0431\u044B\u0442\u0438\u0435, \u0433\u0435\u043D\u0435\u0440\u0438\u0440\u0443\u0435\u043C\u043E\u0435 \u043F\u0440\u0438 \u043A\u0430\u0436\u0434\u043E\u043C \u0447\u0442\u0435\u043D\u0438\u0438 \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u044B
event add <<ReadTemperature>> <Control-p>

# \u041F\u0430\u043D\u0435\u043B\u044C \u0437\u0430\u043A\u043B\u0430\u0434\u043E\u043A
ttk::notebook $w.nb
pack $w.nb -fill both -expand 1 -padx 2 -pady 3
ttk::notebook::enableTraversal $w.nb

# \u0417\u0430\u043A\u043B\u0430\u0434\u043A\u0430 "\u0418\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0435"
ttk::frame $w.nb.m
$w.nb add $w.nb.m -text " \u0418\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u0435 "

# \u0420\u0430\u0437\u0434\u0435\u043B "\u0423\u043F\u0440\u0430\u0432\u043B\u0435\u043D\u0438\u0435"
set p [ttk::labelframe $w.nb.m.ctl -text " \u0423\u043F\u0440\u0430\u0432\u043B\u0435\u043D\u0438\u0435 " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::button $p.measure -text "\u0421\u043D\u044F\u0442\u044C \u0442\u043E\u0447\u043A\u0443" -state disabled -command makeMeasurement -image ::img::next -compound left] -row 0 -column 0 -sticky w
grid [ttk::checkbutton $p.suspend -command toggleSuspend -image ::img::pause -compound left -style Toolbutton -state disabled -text "\u041F\u0440\u0438\u043E\u0441\u0442\u0430\u043D\u043E\u0432\u0438\u0442\u044C \u0437\u0430\u043F\u0438\u0441\u044C"] -row 0 -column 1 -sticky w
grid [ttk::entry $p.comment -textvariable measureComment] -row 0 -column 2 -sticky we
grid [ttk::button $p.addComment -text "\u0414\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u043A\u043E\u043C\u043C\u0435\u043D\u0442\u0430\u0440\u0438\u0439" -state disabled -command addComment -image ::img::edit -compound left] -row 0 -column 3 -sticky w
grid [ttk::button $p.stop -text "\u041E\u0441\u0442\u0430\u043D\u043E\u0432\u0438\u0442\u044C \u0437\u0430\u043F\u0438\u0441\u044C" -command terminateMeasure -state disabled -image ::img::stop -compound left] -row 0 -column 4 -sticky e
grid [ttk::button $p.start -text "\u041D\u0430\u0447\u0430\u0442\u044C \u0437\u0430\u043F\u0438\u0441\u044C" -command startMeasure -image ::img::start -compound left] -row 0 -column 5 -sticky e

grid columnconfigure $p { 0 2 4 5 } -pad 10
grid columnconfigure $p { 1 3 } -pad 50
grid columnconfigure $p { 2 } -weight 1
grid rowconfigure $p { 0 1 } -pad 5

# \u0420\u0430\u0437\u0434\u0435\u043B "\u0420\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F"
set p [ttk::labelframe $w.nb.m.v -text " \u0420\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F " -pad 10]
pack $p -fill x -side bottom -padx 10 -pady 5

grid [ttk::label $p.lc -text "\u0422\u043E\u043A:"] -row 0 -column 0 -sticky w
grid [ttk::entry $p.ec -textvariable runtime(current) -state readonly] -row 0 -column 1 -sticky we

grid [ttk::label $p.lv -text "\u041D\u0430\u043F\u0440\u044F\u0436\u0435\u043D\u0438\u0435:"] -row 0 -column 3 -sticky w
grid [ttk::entry $p.ev -textvariable runtime(voltage) -state readonly] -row 0 -column 4 -sticky we

grid [ttk::label $p.lr -text "\u0421\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u0435:"] -row 0 -column 6 -sticky w
grid [ttk::entry $p.er -textvariable runtime(resistance) -state readonly] -row 0 -column 7 -sticky we

grid [ttk::label $p.lp -text "\u041C\u043E\u0449\u043D\u043E\u0441\u0442\u044C:"] -row 0 -column 9 -sticky w
grid [ttk::entry $p.ep -textvariable runtime(power) -state readonly] -row 0 -column 10 -sticky we

grid [ttk::label $p.lt -text "\u0422\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u0430:"] -row 1 -column 0 -sticky w
grid [ttk::entry $p.et -textvariable runtime(temperature) -state readonly] -row 1 -column 1 -sticky we

grid [ttk::label $p.lder -text "\u041F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u043D\u0430\u044F:"] -row 1 -column 3 -sticky w
grid [ttk::entry $p.eder -textvariable runtime(derivative1) -state readonly] -row 1 -column 4 -sticky we

grid columnconfigure $p { 0 1 3 4 5 6 7 8 9 10 } -pad 5
grid columnconfigure $p { 2 5 8 } -minsize 20
grid columnconfigure $p { 1 4 7 } -weight 1
grid rowconfigure $p { 0 1 2 3 } -pad 5

# \u0420\u0430\u0437\u0434\u0435\u043B "\u0413\u0440\u0430\u0444\u0438\u043A"
set p [ttk::labelframe $w.nb.m.c -text " \u0422\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u043D\u0430\u044F \u0437\u0430\u0432\u0438\u0441\u0438\u043C\u043E\u0441\u0442\u044C " -pad 2]
pack $p -fill both -padx 10 -pady 5 -expand 1

set chartR_T [canvas $p.r_T -width 200 -height 200]
grid $chartR_T -row 0 -column 0 -sticky news
measure::chart::staticChart -xlabel "T, \u041A" -ylabel "R, \u041E\u043C" -dots 1 -lines 1 $chartR_T
measure::chart::${chartR_T}::series test -order 1 -maxCount 10 -color #7f7fff
measure::chart::${chartR_T}::series refined -order 2 -maxCount 200 -thinout -color green
measure::chart::${chartR_T}::series result -order 3 -maxCount 200 -thinout -color blue

set chartR_t [canvas $p.r_t -width 200 -height 200]
grid $chartR_t -row 0 -column 1 -sticky news
measure::chart::movingChart -ylabel "R, \u041E\u043C" -linearTrend $chartR_t

set chartT_t [canvas $p.t_t -width 200 -height 200]
grid $chartT_t -row 1 -column 0 -sticky news
measure::chart::movingChart -ylabel "T, \u041A" -linearTrend $chartT_t

set chartdT_t [canvas $p.dt_t -width 200 -height 200]
grid $chartdT_t -row 1 -column 1 -sticky news
measure::chart::movingChart -ylabel "dT/dt, \u041A/\u043C\u0438\u043D" -linearTrend $chartdT_t

grid columnconfigure $p { 0 1 } -weight 1
grid rowconfigure $p { 0 1 } -weight 1

place [ttk::button $p.cb -text "\u041E\u0447\u0438\u0441\u0442\u0438\u0442\u044C" -command clearResults] -anchor ne -relx 1.0 -rely 0.0

# \u0417\u0430\u043A\u043B\u0430\u0434\u043A\u0430 "\u041F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F"
ttk::frame $w.nb.ms
$w.nb add $w.nb.ms -text " \u041F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F "

grid [ttk::frame $w.nb.ms.l] -column 0 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.r] -column 1 -row 0 -sticky nwe
grid [ttk::frame $w.nb.ms.b] -column 0 -columnspan 2 -row 1 -sticky we

grid columnconfigure $w.nb.ms { 0 1 } -weight 1

# \u041B\u0435\u0432\u0430\u044F \u043A\u043E\u043B\u043E\u043D\u043A\u0430

# \u041D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u0441\u043F\u043E\u0441\u043E\u0431\u0430 \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u0438
set p [ttk::labelframe $w.nb.ms.l.prog -text " \u041C\u0435\u0442\u043E\u0434 \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u0438 " -pad 10]

grid [ttk::label $p.ltime -text "\u0412\u0440\u0435\u043C\u0435\u043D\u043D\u0430\u044F \u0437\u0430\u0432\u0438\u0441\u0438\u043C\u043E\u0441\u0442\u044C:"] -row 0 -column 0 -sticky w
grid [ttk::radiobutton $p.time -value 0 -variable settings(prog.method) -command toggleProgControls] -row 0 -column 1 -sticky e

grid [ttk::label $p.ltimeStep -text "  \u0412\u0440\u0435\u043C\u0435\u043D\u043D\u043E\u0439 \u0448\u0430\u0433, \u043C\u0441:"] -row 1 -column 0 -sticky w
grid [ttk::spinbox $p.timeStep -width 10 -textvariable settings(prog.time.step) -from 0 -to 1000000 -increment 100 -validate key -validatecommand {string is double %P}] -row 1 -column 1 -sticky e

grid [ttk::label $p.ltemp -text "\u0422\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u043D\u0430\u044F \u0437\u0430\u0432\u0438\u0441\u0438\u043C\u043E\u0441\u0442\u044C:"] -row 2 -column 0 -sticky w
grid [ttk::radiobutton $p.temp -value 1 -variable settings(prog.method) -command toggleProgControls] -row 2 -column 1 -sticky e

grid [ttk::label $p.ltempStep -text "  \u0422\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u043D\u044B\u0439 \u0448\u0430\u0433, \u041A:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.tempStep -width 10 -textvariable settings(prog.temp.step) -from 0 -to 1000 -increment 1 -validate key -validatecommand {string is double %P}] -row 3 -column 1 -sticky e

grid [ttk::label $p.lman -text "\u0412\u0440\u0443\u0447\u043D\u0443\u044E:"] -row 4 -column 0 -sticky w
grid [ttk::radiobutton $p.man -value 2 -variable settings(prog.method) -command toggleProgControls] -row 4 -column 1 -sticky e

grid columnconfigure $p {0 1} -pad 5
grid rowconfigure $p {0 1 2 3 4} -pad 5
grid columnconfigure $p { 1 } -weight 1

pack $p -fill x -padx 10 -pady 5

# \u041D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u043F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043A\u0438

set p [ttk::labelframe $w.nb.ms.l.switch -text " \u041F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043A\u0430 " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::switchControls $p switch
# following widgets are not used in this app version
destroy "${p}.lswitchVoltage"
destroy "${p}.switchVoltage"

grid [ttk::label $p.lstep -text "\u041A\u043E\u043B-\u0432\u043E \u0442\u043E\u0447\u0435\u043A \u043F\u0435\u0440\u0435\u0434 \u043F\u0435\u0440\u0435\u043F\u043E\u043B\u044E\u0441\u043E\u0432\u043A\u043E\u0439:"] -row 3 -column 0 -sticky w
grid [ttk::spinbox $p.step -width 10 -textvariable settings(switch.step) -from 1 -to 100 -increment 1 -validate key -validatecommand {string is integer %P}] -row 3 -column 1 -sticky e

# \u041F\u0440\u0430\u0432\u0430\u044F \u043A\u043E\u043B\u043E\u043D\u043A\u0430

# \u0420\u0430\u0437\u0434\u0435\u043B \u043D\u0430\u0441\u0442\u0440\u043E\u0435\u043A \u043C\u0435\u0442\u043E\u0434\u0430 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u0442\u043E\u043A\u0430
set p [ttk::labelframe $w.nb.ms.r.curr -text " \u041C\u0435\u0442\u043E\u0434 \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u044F " -pad 10]
pack $p -fill x -padx 10 -pady 5
measure::widget::resistanceMethodControls $p current
# following widgets are not used in this app version
destroy "${p}.lvolt"
destroy "${p}.volt"
destroy "${p}.lr"
destroy "${p}.r"
destroy "${p}.lrerr"
destroy "${p}.rerr"
destroy "${p}.lman"
destroy "${p}.man"

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# \u041D\u0438\u0436\u043D\u0438\u0439 \u0440\u0430\u0437\u0434\u0435\u043B

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

grid columnconfigure $w.nb.m {0 1} -pad 5
grid rowconfigure $w.nb.m {0 1} -pad 5

# \u0417\u0430\u043A\u043B\u0430\u0434\u043A\u0430 "\u041E\u0431\u0440\u0430\u0437\u0435\u0446"
ttk::frame $w.nb.dut
$w.nb add $w.nb.dut -text " \u041E\u0431\u0440\u0430\u0437\u0435\u0446 "

# \u041D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438 \u043F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u043E\u0432 \u043E\u0431\u0440\u0430\u0437\u0446\u0430
set p [ttk::labelframe $w.nb.dut.dut -text " \u0413\u0435\u043E\u043C\u0435\u0442\u0440\u0438\u0447\u0435\u0441\u043A\u0438\u0435 \u043F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::dutControls $p dut

# \u0420\u0430\u0437\u0434\u0435\u043B \u043D\u0430\u0441\u0442\u0440\u043E\u0435\u043A \u0432\u044B\u0432\u043E\u0434\u0430
set p [ttk::labelframe $w.nb.dut.reg -text " \u0424\u0430\u0439\u043B\u044B " -pad 10]

grid [ttk::label $p.lname -text "\u0418\u043C\u044F \u0444\u0430\u0439\u043B\u0430 \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442\u043E\u0432: " -anchor e] -row 0 -column 0 -sticky w
grid [ttk::entry $p.name -textvariable settings(result.fileName)] -row 0 -column 1 -columnspan 4 -sticky we

grid [ttk::label $p.ltname -text "\u0418\u043C\u044F \u0444\u0430\u0439\u043B\u0430 \u0442\u0440\u0430\u0441\u0441\u0438\u0440\u043E\u0432\u043A\u0438: " -anchor e] -row 1 -column 0 -sticky w
grid [ttk::entry $p.tname -textvariable settings(trace.fileName)] -row 1 -column 1 -columnspan 4 -sticky we

grid [ttk::label $p.lformat -text "\u0424\u043E\u0440\u043C\u0430\u0442 \u0444\u0430\u0439\u043B\u043E\u0432:"] -row 3 -column 0 -sticky w
grid [ttk::combobox $p.format -width 10 -textvariable settings(result.format) -state readonly -values [list TXT CSV]] -row 3 -column 1 -columnspan 2 -sticky w

grid [ttk::label $p.lrewrite -text "\u041F\u0435\u0440\u0435\u043F\u0438\u0441\u0430\u0442\u044C \u0444\u0430\u0439\u043B\u044B:"] -row 3 -column 3 -sticky e
grid [ttk::checkbutton $p.rewrite -variable settings(result.rewrite)] -row 3 -column 4 -sticky e

grid [ttk::label $p.lcomment -text "\u041A\u043E\u043C\u043C\u0435\u043D\u0442\u0430\u0440\u0438\u0439: " -anchor e] -row 4 -column 0 -sticky w
grid [ttk::entry $p.comment -textvariable settings(result.comment)] -row 4 -column 1  -columnspan 4 -sticky we

grid [ttk::button $p.open -text "\u041E\u0442\u043A\u0440\u044B\u0442\u044C \u0444\u0430\u0439\u043B" -command openResults -image ::img::open -compound left] -row 5 -column 0 -columnspan 5 -sticky e

grid columnconfigure $p {0 1 3 4} -pad 5
grid columnconfigure $p { 2 } -weight 1
grid rowconfigure $p { 0 1 2 3 4 } -pad 5
grid rowconfigure $p { 5 } -pad 10

pack $p -fill x -padx 10 -pady 5

# \u0417\u0430\u043A\u043B\u0430\u0434\u043A\u0430 "\u041F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u044F"
ttk::frame $w.nb.setup
$w.nb add $w.nb.setup -text " \u041F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u044F "

set p [ttk::labelframe $w.nb.setup.switch -text " \u0411\u043B\u043E\u043A \u0440\u0435\u043B\u0435 " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::mvu8Controls $p "switch"

set p [ttk::labelframe $w.nb.setup.mm -text " \u0412\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440/\u043E\u043C\u043C\u0435\u0442\u0440 \u043D\u0430 \u043E\u0431\u0440\u0430\u0437\u0446\u0435 " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::mmControls $p mm

set p [ttk::labelframe $w.nb.setup.cmm -text " \u0410\u043C\u043F\u0435\u0440\u043C\u0435\u0442\u0440/\u0432\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440 \u043D\u0430 \u044D\u0442\u0430\u043B\u043E\u043D\u0435 " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::mmControls $p cmm

set p [ttk::labelframe $w.nb.setup.ps -text " \u0418\u0441\u0442\u043E\u0447\u043D\u0438\u043A \u043F\u0438\u0442\u0430\u043D\u0438\u044F " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::psControls $p ps

# \u0417\u0430\u043A\u043B\u0430\u0434\u043A\u0430 "\u041F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u044B"
ttk::frame $w.nb.tsetup
$w.nb add $w.nb.tsetup -text " \u041F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0438\u0437\u043C\u0435\u0440\u0435\u043D\u0438\u044F \u0442\u0435\u043C\u043F\u0435\u0440\u0430\u0442\u0443\u0440\u044B "

set p [ttk::labelframe $w.nb.tsetup.tcc -text " \u0421\u043F\u043E\u0441\u043E\u0431 \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u044F \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u044B " -pad 10]

grid [ttk::label $p.ltime -text "\u041A \u0432\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440\u0443:"] -row 0 -column 0 -sticky w
grid [ttk::radiobutton $p.time -value 0 -variable settings(tc.method) -command toggleTcMethodControls] -row 0 -column 1 -sticky e

grid [ttk::label $p.ltemp -text "\u041A \u0422\u0420\u041C-201:"] -row 0 -column 3 -sticky w
grid [ttk::radiobutton $p.temp -value 1 -variable settings(tc.method) -command toggleTcMethodControls] -row 0 -column 4 -sticky e

grid [ttk::label $p.lpad -text " "] -row 0 -column 2 -sticky w

grid columnconfigure $p {0 1 3 4} -pad 5
grid rowconfigure $p {0 1} -pad 5
grid columnconfigure $p { 2 } -pad 50

pack $p -fill x -padx 10 -pady 5

set p [ttk::labelframe $w.nb.tsetup.tcmm -text " \u0412\u043E\u043B\u044C\u0442\u043C\u0435\u0442\u0440 \u043D\u0430 \u0442\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u0435 " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::mmControls $p tcmm

set p [ttk::labelframe $w.nb.tsetup.tcm -text " \u0418\u0437\u043C\u0435\u0440\u0438\u0442\u0435\u043B\u044C-\u0440\u0435\u0433\u0443\u043B\u044F\u0442\u043E\u0440 \u0422\u0420\u041C-201 " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::trm201Controls $p "tcm"

set p [ttk::labelframe $w.nb.tsetup.tc -text " \u0422\u0435\u0440\u043C\u043E\u043F\u0430\u0440\u0430 " -pad 10]
pack $p -fill x -padx 10 -pady 5
::measure::widget::thermoCoupleControls -nb $w.nb -workingTs $w.nb.m -currentTs $w.nb.tsetup $p tc

# \u0421\u0442\u0430\u043D\u0434\u0430\u0440\u0442\u043D\u0430\u044F \u043F\u0430\u043D\u0435\u043B\u044C
::measure::widget::std-bottom-panel $w

# \u0427\u0438\u0442\u0430\u0435\u043C \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438
measure::config::read

# \u041D\u0430\u0441\u0442\u0440\u0430\u0438\u0432\u0430\u0435\u043C \u044D\u043B\u0435\u043C\u0435\u043D\u0442\u044B \u0443\u043F\u0440\u0430\u0432\u043B\u0435\u043D\u0438\u044F
toggleTestResistance
toggleProgControls
toggleTcMethodControls

# \u0417\u0430\u043F\u0443\u0441\u043A\u0430\u0435\u043C \u0442\u0435\u0441\u0442\u0435\u0440
startTester

#vwait forever
thread::wait

