-- ©2009 Andreas Beier & c't - Magazin für Computertechnik (adb@ctmagazin.de)

property daemonsDataSource : null


on clicked theObject
	if name of theObject is equal to "addBtn" then
		set sourceFolder to (POSIX path of (choose folder with prompt "Quellverzeichnis auswählen"))
		set destFolder to (POSIX path of (choose folder with prompt "Backup-Verzeichnis auswählen"))
		
		if sourceFolder is not destFolder then
			-- Daemon einrichten
			-- eindeutigen Namen für MakeBackupAgent.plist ermitteln
			set folderName to call method "lastPathComponent" of sourceFolder
			set randomPart to (randomPartForFilename("Library:LaunchDaemons:", "MBA_" & folderName & "_", ".plist") as text)
			set daemonName to "MBA_" & folderName & "_" & randomPart & ".plist"
			
			-- eindeutigen Namen für Script zum Anlegen dateispezifischer Daemons ermitteln
			set agentManName to "AM_" & folderName & "_" & randomPart
			
			-- eindeutigen Namen für Backup-Script ermitteln
			set triggerbackupName to "triggerback_" & folderName & "_" & randomPart
			
			-- Vorlage MakeBackupAgent.plist einlesen
			set plistPath to path for resource "MakeBackupAgent" extension "template"
			set plistContents to call method "dictionaryWithContentsOfFile:" of class "NSDictionary" with parameter plistPath
			
			-- Vorlage MakeBackupAgent.plist anpassen
			set |Label| of plistContents to "de.ctmagazin.TriggerBack." & daemonName
			set |WatchPaths| of plistContents to {sourceFolder}
			set |backupSource| of plistContents to sourceFolder
			set |backupDest| of plistContents to destFolder
			set |ProgramArguments| of plistContents to {"/usr/local/bin/" & agentManName}
			
			-- Daemon abspeichern
			set success to call method "writeToFile:atomically:" of plistContents with parameters {"/private/tmp/" & daemonName, true}
			do shell script ("/bin/mv '/private/tmp/" & daemonName & "' /Library/LaunchDaemons/") with administrator privileges
			do shell script ("/bin/chmod u=rw,go=r '/Library/LaunchDaemons/" & daemonName & "'") with administrator privileges
			do shell script ("/usr/sbin/chown root:wheel '/Library/LaunchDaemons/" & daemonName & "'") with administrator privileges
			
			-- Vorlage AgentMan einlesen
			set agentManPath to path for resource "AgentMan" extension "template"
			set agentManContents to call method "stringWithContentsOfFile:encoding:error:" of class "NSString" with parameters {agentManPath, 12, null}
			
			-- Vorlage AgentMan anpassen
			set agentManContents to call method "stringByReplacingOccurrencesOfString:withString:" of agentManContents with parameters {"SSSSS", sourceFolder}
			set agentManContents to call method "stringByReplacingOccurrencesOfString:withString:" of agentManContents with parameters {"BBBBB", destFolder}
			set agentManContents to call method "stringByReplacingOccurrencesOfString:withString:" of agentManContents with parameters {"LLLLL", "/tmp/" & folderName & "_last_" & randomPart}
			set agentManContents to call method "stringByReplacingOccurrencesOfString:withString:" of agentManContents with parameters {"BSBSBS", triggerbackupName}
			set agentManContents to call method "stringByReplacingOccurrencesOfString:withString:" of agentManContents with parameters {"RPRPRP", randomPart}
			
			-- AgentMan abspeichern
			set success to call method "writeToFile:atomically:" of agentManContents with parameters {"/private/tmp/" & agentManName, true}
			do shell script ("/bin/mv '/private/tmp/" & agentManName & "' /usr/local/bin/") with administrator privileges
			do shell script ("/bin/chmod +x '/usr/local/bin/" & agentManName & "'") with administrator privileges
			do shell script ("/usr/sbin/chown root:wheel '/usr/local/bin/" & agentManName & "'") with administrator privileges
			
			-- Vorlage triggerbackup einlesen
			set triggerbackupPath to path for resource "triggerback" extension "template"
			set triggerbackupContents to call method "stringWithContentsOfFile:encoding:error:" of class "NSString" with parameters {triggerbackupPath, 12, null}
			
			-- Vorlage triggerbackup anpassen
			set triggerbackupContents to call method "stringByReplacingOccurrencesOfString:withString:" of triggerbackupContents with parameters {"SSSSS", sourceFolder}
			set triggerbackupContents to call method "stringByReplacingOccurrencesOfString:withString:" of triggerbackupContents with parameters {"BBBBB", destFolder}
			
			-- triggerbackup abspeichern
			set success to call method "writeToFile:atomically:" of triggerbackupContents with parameters {"/private/tmp/" & triggerbackupName, true}
			do shell script ("/bin/mv '/private/tmp/" & triggerbackupName & "' /usr/local/bin/") with administrator privileges
			do shell script ("/bin/chmod +x '/usr/local/bin/" & triggerbackupName & "'") with administrator privileges
			do shell script ("/usr/sbin/chown root:wheel " & "'/usr/local/bin/" & triggerbackupName & "'") with administrator privileges
			
			-- die ganze Sache aktivieren
			do shell script ("/bin/launchctl load -w '/Library/LaunchDaemons/" & daemonName & "'") with administrator privileges
			
			-- am Ende noch Tabelle aktualisieren
			set theRow to make new data row at the end of the data rows of daemonsDataSource
			set contents of data cell "source" of theRow to sourceFolder
			set contents of data cell "dest" of theRow to destFolder
			set contents of data cell "daemonName" of theRow to daemonName
		else
			display dialog "Quell- und Backup-Verzeichnis dürfen nicht identsich sein!" buttons {"OK"} default button 1
		end if
		
	else if name of theObject is "removeBtn" then
		set tableView to table view "daemonsTable" of scroll view "daemonsScrollView" of window of theObject
		set selectedDataRows to selected data rows of tableView
		
		if (count of selectedDataRows) > 0 then
			display dialog "Wollen Sie die ausgewählten Backup-Agenten löschen?" buttons {"Abbrechen", "Ja"} default button 1
			
			repeat with oneRow in selectedDataRows
				set sourceFolder to contents of data cell "source" of oneRow
				set destFolder to contents of data cell "dest" of oneRow
				set daemonName to contents of data cell "daemonName" of oneRow
				delete oneRow
				
				-- Daemons und Skripte eliminieren
				-- zufällige Komponente aus ("MBA_" & folderName & "_" & randomPart & ".plist") extrahieren
				set parts to call method "componentsSeparatedByString:" of daemonName with parameter "_"
				set lastPart to last item of parts
				set randomPart to (characters 1 thru ((length of lastPart) - 6) of lastPart) as text
				
				-- LaunchDaemon "MakeBackupAgent" stoppen und löschen
				do shell script ("/bin/launchctl unload -w '/Library/LaunchDaemons/" & daemonName & "'") with administrator privileges
				do shell script ("/bin/rm '/Library/LaunchDaemons/" & daemonName & "'") with administrator privileges
				
				-- restliche LaunchDaemons und Skripte ermitteln, stoppen und löschen
				tell application "Finder"
					set allDaemons to name of every file in ((POSIX file "/Library/LaunchDaemons/") as alias)
					set allScripts to name of every file in ((POSIX file "/usr/local/bin/") as alias)
				end tell
				
				repeat with oneDaemon in allDaemons
					if oneDaemon ends with lastPart then
						do shell script ("/bin/launchctl unload -w '/Library/LaunchDaemons/" & oneDaemon & "'") with administrator privileges
						do shell script ("/bin/rm '/Library/LaunchDaemons/" & oneDaemon & "'") with administrator privileges
					end if
				end repeat
				
				repeat with oneScript in allScripts
					if oneScript ends with randomPart then
						do shell script ("/bin/rm '/usr/local/bin/" & oneScript & "'") with administrator privileges
					end if
				end repeat
				
			end repeat -- selectedDataRows
		end if
		
	else if name of theObject is "sourceBtn" then
		set tableView to table view "daemonsTable" of scroll view "daemonsScrollView" of window of theObject
		set selectedDataRows to selected data rows of tableView
		
		if (count of selectedDataRows) > 0 then
			set oneRow to item 1 of selectedDataRows
			set sourceFolder to (POSIX file (contents of data cell "source" of oneRow)) as alias
			tell application "Finder"
				reveal sourceFolder
				activate
			end tell
		end if
		
	else if name of theObject is "destBtn" then
		set tableView to table view "daemonsTable" of scroll view "daemonsScrollView" of window of theObject
		set selectedDataRows to selected data rows of tableView
		
		if (count of selectedDataRows) > 0 then
			set oneRow to item 1 of selectedDataRows
			set destFolder to (POSIX file (contents of data cell "dest" of oneRow)) as alias
			tell application "Finder"
				reveal destFolder
				activate
			end tell
		end if
		
	end if
end clicked


on will open theObject
	if daemonsDataSource is null then
		set daemonsDataSource to data source of table view "daemonsTable" of scroll view "daemonsScrollView" of theObject
		
		tell daemonsDataSource
			make new data column at the end of the data columns with properties {name:"source"}
			make new data column at the end of the data columns with properties {name:"dest"}
			make new data column at the end of the data columns with properties {name:"daemonName"}
		end tell
		
		-- Daemons ermitteln
		tell application "Finder"
			set allDaemons to name of every file in ((POSIX file "/Library/LaunchDaemons/") as alias)
		end tell
		
		repeat with oneDaemon in allDaemons
			set {sourcePath, destPath} to parametersOfDaemon(oneDaemon)
			
			if (sourcePath is not null) and (destPath is not null) then
				set theRow to make new data row at the end of the data rows of daemonsDataSource
				set contents of data cell "source" of theRow to sourcePath
				set contents of data cell "dest" of theRow to destPath
				set contents of data cell "daemonName" of theRow to oneDaemon
			end if
		end repeat
	end if
	
	-- GUI anpassen
	set enabled of button "removeBtn" of window "main" to false
	set enabled of button "sourceBtn" of window "main" to false
	set enabled of button "destBtn" of window "main" to false
end will open


on selection changed theObject
	set theWindow to window of theObject
	
	if name of theObject is "daemonsTable" then
		set selectedDataRows to selected data rows of theObject
		
		if (count of selectedDataRows) = 0 then
			set enabled of button "removeBtn" of theWindow to false
			set enabled of button "sourceBtn" of theWindow to false
			set enabled of button "destBtn" of theWindow to false
		else
			set enabled of button "removeBtn" of theWindow to true
			set enabled of button "sourceBtn" of theWindow to true
			set enabled of button "destBtn" of theWindow to true
		end if
	end if
end selection changed


on parametersOfDaemon(oneDaemon)
	set daemonContents to call method "dictionaryWithContentsOfFile:" of class "NSDictionary" with parameter ("/Library/LaunchDaemons/" & oneDaemon)
	
	try
		return {(|backupSource| of daemonContents), (|backupDest| of daemonContents)}
	end try
	
	return {null, null}
end parametersOfDaemon


on rnd()
	return random number from 10000000 to 100000000 with seed (random number 10000000)
end rnd


on randomPartForFilename(pathPrefix, filePrefix, fileSuffix)
	local thePath, fileName
	
	repeat
		set r to rnd()
		set fileName to filePrefix & r & fileSuffix
		set thePath to ((path to startup disk as string) & fileName) as string
		
		try
			set i to info for alias thePath
		on error
			--"info for" hat einen Fehler gemeldet, es existiert also keine Datei mit dem überprüften Namen
			-- Der Name ist also brauchbar.
			exit repeat
		end try
	end repeat
	
	return r
end randomPartForFilename