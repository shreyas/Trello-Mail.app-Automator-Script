to logit(log_string, log_file)
	(* do shell script ¬
		"echo `date '+%Y-%m-%d %T: '`\"" & log_string & ¬
		"\" >> $HOME/Library/Logs/" & log_file & ".log" *)
end logit

on run {input, parameters}
	
	set theAppKey to "** appKey **"
	set theUserToken to "** apple mail token **"
	
	set theBoardTitle to "ToDos" -- whatever appropriate name is
	set theListTitle to "Inbox"
	set success to true
	
	set the standard_characters to "abcdefghijklmnopqrstuvwxyz0123456789[]()-,:/;.\n " -- shortcut to filter out characters that wont survive
	-- set the escaped_characters to ",:;//"
	tell application "Mail"
		set selectedMessages to selection
		
		if (count of selectedMessages) is equal to 0 then
		else
			set theMessage to item 1 of selectedMessages
			
			set theSubject to subject of theMessage
			set theSender to sender of theMessage
			set theMessageId to message id of theMessage
			set theDateReceived to date received of theMessage
			set theMessageBody to content of theMessage
			tell (sender of theMessage)
				set theSenderName to (extract name from it)
			end tell
			
			(* if length of theMessageBody < 200 then
				set bodyBrief to theMessageBody
			else
				set bodyBrief to ((characters 1 thru 200 of theMessageBody) as string)
			end if *)
			set bodyBrief to theMessageBody
			
			set the_encoded_text to ""
			repeat with this_char in bodyBrief
				if this_char is in the standard_characters then
					set the_encoded_text to (the_encoded_text & this_char)
					-- else if this_char is in the escaped_characters then
					-- set the_encoded_text to (the_encoded_text & "\\" & this_char)
				else
					-- can't figure out real encoding so just replace characters that we can't deal with using underscores
					set the_encoded_text to (the_encoded_text & " ")
				end if
			end repeat
			set bodyBrief to the_encoded_text
			
			set the_encoded_subject to ""
			repeat with a_char in theSubject
				if a_char is in the standard_characters then
					set the_encoded_subject to (the_encoded_subject & a_char)
				else
					set the_encoded_subject to (the_encoded_subject & "")
				end if
			end repeat
			set theSubject to the_encoded_subject
			
			if theMessageId is "" then
				tell application "Finder" to display dialog "Could not find the message id for the selected message."
				error 1
			end if
			
			-- creates a URL to the message, sadly it's not working from Chrome.			
			set message_url to "[" & theSubject & "](message://%3C" & theMessageId & "%3E" & ")"
			my logit("DEBUG: prepared the message url to " & message_url, "mail-to-trello-card")
			
			tell application "JSON Helper"
				set jsonString to fetch JSON from "https://trello.com/1/members/my/boards?key=" & theAppKey & "&token=" & theUserToken
				set numBoards to count of jsonString
				
				if numBoards is 0 then
					tell application "Finder" to display dialog "error receiving list of boards"
					error 2
				end if
				
				my logit("DEBUG: received a list of trello boards", "mail-to-trello-card")
				
				set success to false
				repeat with ii from 1 to numBoards
					
					-- get the title
					set boardTitle to |name| of item ii of jsonString as string
					-- see if it's our board, if so we're done.
					if theBoardTitle = boardTitle then
						set boardId to |id| of item ii of jsonString
						log boardId
						set success to true
						exit repeat
					end if
					
				end repeat
				
				if success is false then
					tell application "Finder" to display dialog "Could not find the board with the title " & theBoardTitle
					error 3
				end if
				
				my logit("DEBUG: found the board " & theBoardTitle, "mail-to-trello-card")
				
				-- get the list of my boards
				set jsonString to fetch JSON from "https://trello.com/1/boards/" & boardId & "/lists?key=" & theAppKey & "&token=" & theUserToken
				set numLists to count of jsonString
				
				if numLists is 0 then
					tell application "Finder" to display dialog "error receiving list of lists in the board"
					error 4
				end if
				
				my logit("DEBUG: received list of lists in the board", "mail-to-trello-card")
				
				-- for each list
				set success to false
				repeat with ii from 1 to numLists
					
					-- get the title
					set listTitle to |name| of item ii of jsonString as string
					log listTitle
					
					-- see if it's "To Do", if so we're done.
					if theListTitle = listTitle then
						set listId to |id| of item ii of jsonString
						log listId
						set success to true
						exit repeat
					end if
					
				end repeat
				
				if success is false then
					tell application "Finder" to display dialog "Could not find the list with the title " & theListTitle
					error 5
				end if
				
				my logit("DEBUG: found the list with title " & theListTitle, "mail-to-trello-card")
				
				set itemName to theSenderName & ": " & theSubject
				set itemDesc to message_url & return & theDateReceived & return & return & bodyBrief
				
				set curlPostCmd to "curl -s -X POST"
				set curlURL to "https://api.trello.com/1/lists/" & listId & "/cards"
				set curlOpts to "-d name='" & itemName & "' -d desc='" & itemDesc & "' -d key=" & theAppKey & " -d token=" & theUserToken
				
				my logit("DEBUG: about to do curl post with command => " & curlPostCmd & " " & curlURL & " " & curlOpts, "mail-to-trello-card")
				
				set curlOutput to do shell script curlPostCmd & " " & curlURL & " " & curlOpts
				set jsonString to read JSON from curlOutput
				set outputURL to shortUrl of jsonString
				
				my logit("DEBUG: card created at " & outputURL, "mail-to-trello-card")
				
				-- tell application "Google Chrome"
				(* tell application "Safari"
					activate
					if (count every window) = 0 then
						make new window
					end if
					tell window 1 to make new tab with properties {URL:outputURL}
				end tell *)
				
				--tell application "Finder" to display dialog outputURL
				
			end tell
			
		end if
	end tell
	
	return input
end run