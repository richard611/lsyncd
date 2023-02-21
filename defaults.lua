--============================================================================
-- default.lua   Live (Mirror) Syncing Demon
--
-- The default table for the user to access.
-- This default layer 1 functions provide the higher layer functionality.
--
-- License: GPLv2 (see COPYING) or any later version
-- Authors: Axel Kittenberger <axkibe@gmail.com>
--============================================================================

if default
then
	error( 'default already loaded' )
end

--- @diagnostic disable-next-line: lowercase-global
default = { }


--
-- Only this items are inherited from the default
-- table
--
default._merge = {
	action          = true,
	checkgauge      = true,
	collect         = true,
	delay           = true,
	init            = true,
	maxDelays       = true,
	maxProcesses    = true,
	prepare         = true,
}

--
-- used to ensure there aren't typos in the keys
--
default.checkgauge = {
	action        =  true,
	checkgauge    =  true,
	collect       =  true,
	crontab       =  true,
	delay         =  true,
	exitcodes     =  true,
	init          =  true,
	full          =  true,
	maxDelays     =  true,
	maxProcesses  =  true,
	onAttrib      =  true,
	onCreate      =  true,
	onModify      =  true,
	onDelete      =  true,
	onStartup     =  true,
	onMove        =  true,
	onFull        =  true,
	prepare       =  true,
	source        =  true,
	target        =  true,
	tunnel        =  true,
}

--
-- On default action the user's on*** scripts are called.
--
default.action = function
(
	inlet -- the inlet of the active sync.
)
	-- in case of moves getEvent returns the origin and dest of the move
	local event, event2 = inlet.getEvent( )

	local config = inlet.getConfig( )

	local func = config[ 'on'.. event.etype ]

	if type( func ) == 'function'
	then
		func( event, event2 )
	end

	-- if function didnt change the wait status its not interested
	-- in this event -> drop it.
	if event.status == 'wait'
	then
		inlet.discardEvent( event )
	end

end


--
-- Default collector.
--
-- Called when collecting a finished child process
--
default.collect = function
(
	agent,    -- event or event list being collected
	exitcode  -- the exitcode of the spawned process
)
	local config = agent.config

	local rc

	if config.exitcodes
	then
		rc = config.exitcodes[ exitcode ]
	elseif exitcode == 0
	then
		rc = 'ok'
	else
		rc = 'die'
	end

	-- TODO synchronize with similar code before
	if not agent.isList and agent.etype == 'Init'
	then
		if rc == 'ok'
		then
			log(
				'Normal',
				'Startup of ',
				agent.source,
				' -> ',
				agent.target,
				' finished.'
			)
			if settings('onepass')
			then
				log(
					'Normal', 
					'onepass config set, exiting'
				)
				terminate( 0 )
			end
			return 'ok'
		elseif rc == 'again'
		then
			if settings( 'insist' )
			then
				log(
					'Normal',
					'Retrying startup of ',
					agent.source,
					' -> ',
					agent.target,
					': ',
					exitcode
				)

				return 'again'
			else
				log(
					'Error',
					'Temporary or permanent failure on startup of ',
					agent.source,
					' -> ',
					agent.target,
					'. Terminating since "insist" is not set.'
				)

				terminate( -1 )
			end
		elseif rc == 'die'
		then
			log(
				'Error',
				'Failure on startup of ',
				agent.source,
				' -> ',
				agent.target,
				'.'
			)

			terminate( -1 )
		else
			log(
				'Error',
				'Unknown exitcode "',
				exitcode,
				'" on startup of ',
				agent.source,
				' -> ',
				agent.target,
				'.'
			)
			return 'die'
		end
	end

	if agent.isList
	then
		if rc == 'ok'
		then
			log(
				'Normal',
				'Finished a list after exitcode: ',
				exitcode
			)
		elseif rc == 'again'
		then
			log(
				'Normal',
				'Retrying a list after exitcode = ',
				exitcode
			)
		elseif rc == 'die'
		then
			log(
				'Error',
				'Failure with a list with exitcode = ',
				exitcode
			)
		else
			log(
				'Error',
				'Unknown exitcode "',exitcode,'" with a list'
			)

			rc = 'die'
		end
	else
		if rc == 'ok'
		then
			log(
				'Normal',
				'Finished ',
				agent.etype,
				' on ',
				agent.sourcePath,
				' = ',
				exitcode
			)
		elseif rc == 'again'
		then
			log(
				'Normal',
				'Retrying ',
				agent.etype,
				' on ',
				agent.sourcePath,
				' = ',
				exitcode
			)
		elseif rc == 'die'
		then
			log(
				'Error',
				'Failure with ',
				agent.etype,
				' on ',
				agent.sourcePath,
				' = ',
				exitcode
			)
		else
			log(
				'Normal',
				'Unknown exitcode "',
				exitcode,
				'" with ',
				agent.etype,
				' on ',
				agent.sourcePath,
				' = ',
				exitcode
			)

			rc = 'die'
		end
	end

	return rc
end


--
-- Called on the Init event sent
-- on (re)initialization of Lsyncd for every sync
--
default.init = function
(
	event -- the precreated init event.
)
	local config = event.config

	local inlet = event.inlet

	-- user functions
	-- calls a startup if given by user script.
	if type( config.onStartup ) == 'function'
	then
		config.onStartup( event )
		-- TODO honor some return codes of startup like "warmstart".
	end

	if event.status == 'wait'
	then
		-- user script did not spawn anything
		-- thus the blanket event is deleted again.
		inlet.discardEvent( event )
	end
end


--
-- The collapsor tries not to have more than these delays.
-- So the delay queue does not grow too large
-- since calculation for stacking events is n*log( n ) (or so)
--
default.maxDelays = 1000


--
-- The maximum number of processes Lsyncd will
-- simultanously spawn for this sync.
--
default.maxProcesses = 1


--
-- Exitcodes of rsync and what to do.
-- TODO move to rsync
--
default.rsyncExitCodes = {

	--
	-- if another config provides the same table
	-- this will not be inherited (merged) into that one
	--
	-- if it does not, integer keys are to be copied
	-- verbatim
	--
	_merge  = false,
	_verbatim = true,

	[   0 ] = 'ok',
	[   1 ] = 'die',
	[   2 ] = 'die',
	[   3 ] = 'again',
	[   4 ] = 'die',
	[   5 ] = 'again',
	[   6 ] = 'again',
	[  10 ] = 'again',
	[  11 ] = 'again',
	[  12 ] = 'again',
	[  14 ] = 'again',
	[  20 ] = 'again',
	[  21 ] = 'again',
	[  22 ] = 'again',

	-- partial transfers are ok, since Lsyncd has registered the event that
	-- caused the transfer to be partial and will recall rsync.
	[  23 ] = 'ok',
	[  24 ] = 'ok',

	[  25 ] = 'die',
	[  30 ] = 'again',
	[  35 ] = 'again',

	[ 255 ] = 'again',
}


--
-- Exitcodes of ssh and what to do.
--
default.sshExitCodes =
{
	--
	-- if another config provides the same table
	-- this will not be inherited (merged) into that one
	--
	-- if it does not, integer keys are to be copied
	-- verbatim
	--
	_merge = false,
	_verbatim = true,

	[   0 ] = 'ok',
	[ 255 ] = 'again',
}


--
-- Minimum seconds between two writes of the status file.
--
default.statusInterval = 10


--
-- Checks all keys to be in the checkgauge.
--
local function check
(
	config,
	gauge,
	subtable,
	level
)
	for k, v in pairs( config )
	do
		if not gauge[ k ]
		then
			error(
				'Parameter "' .. subtable .. k .. '" unknown.'
				.. ' ( if this is not a typo add it to checkgauge )',
				level
			);
		end

		if type( gauge [ k ] ) == 'table'
		then
			if type( v ) ~= 'table'
			then
				error(
					'Parameter "' .. subtable .. k .. '" must be a table.',
					level
				)
			end

			check(
				config[ k ],
				gauge[ k ],
				subtable .. k .. '.',
				level + 1
			)
		end
	end
end


default.prepare = function
(
	config, -- the config to prepare for
	level   -- current callback level for error reporting
)

	local gauge = config.checkgauge

	if not gauge then return end

	check( config, gauge, '', level + 1 )
end


if not default then error( 'default not loaded' ) end

if default.rsync then error( 'default-rsync already loaded' ) end


local rsync = { }

default.rsync = rsync

-- uses default collect

--
-- used to ensure there aren't typos in the keys
--
rsync.checkgauge = {

	-- unsets default user action handlers
	onCreate    =  false,
	onModify    =  false,
	onDelete    =  false,
	onStartup   =  false,
	onMove      =  false,

	delete      =  true,
	exclude     =  true,
	excludeFrom =  true,
	filter      =  true,
	filterFrom  =  true,
	target      =  true,
	batchSizeLimit = true,

	rsync  = {
		acls              =  true,
		append            =  true,
		append_verify     =  true,
		archive           =  true,
		backup            =  true,
		backup_dir        =  true,
		binary            =  true,
		bwlimit           =  true,
		checksum          =  true,
		chown             =  true,
		chmod             =  true,
		compress          =  true,
		copy_dirlinks     =  true,
		copy_links        =  true,
		copy_unsafe_links =  true,
		cvs_exclude       =  true,
		delete_excluded   =  true,
		dry_run           =  true,
		executability     =  true,
		existing          =  true,
		group             =  true,
		groupmap          =  true,
		hard_links        =  true,
		ignore_times      =  true,
		inplace           =  true,
		ipv4              =  true,
		ipv6              =  true,
		keep_dirlinks     =  true,
		links             =  true,
		one_file_system   =  true,
		omit_dir_times    =  true,
		omit_link_times   =  true,
		owner             =  true,
		password_file     =  true,
		perms             =  true,
		protect_args      =  true,
		prune_empty_dirs  =  true,
		quiet             =  true,
		rsh               =  true,
		rsync_path        =  true,
		sparse            =  true,
		suffix            =  true,
		temp_dir          =  true,
		timeout           =  true,
		times             =  true,
		update            =  true,
		usermap           =  true,
		verbose           =  true,
		whole_file        =  true,
		xattrs            =  true,
		_extra            =  true,
	},
}


-- internal function to actually do the transfer
local run_action = function
	(
		inlet,
		elist
	)
	local config = inlet.getConfig( )

	local substitudes = inlet.getSubstitutionData(elist, {})
	local target = substitudeCommands(config.target, substitudes)

	--
	-- Replaces what rsync would consider filter rules by literals
	--
	local function sub
	(
		p  -- pattern
	)
		if not p then return end

		return p:
			gsub( '%?', '\\?' ):
			gsub( '%*', '\\*' ):
			gsub( '%[', '\\[' ):
			gsub( '%]', '\\]' )
	end

	--
	-- Gets the list of paths for the event list
	--
	-- Deletes create multi match patterns
	--
	local paths = elist.getPaths(
		function
		(
			etype,  -- event type
			path1,  -- path
			path2   -- path to for move events
		)
			if string.byte( path1, -1 ) == 47 and etype == 'Delete'
			then
				return sub( path1 )..'***', sub( path2 )
			else
				return sub( path1 ), sub( path2 )
			end
		end
	)

	-- stores all filters by integer index
	local filterI = { }

	-- stores all filters with path index
	local filterP = { }

	-- adds one path to the filter
	local function addToFilter
	(
		path
	)
		if filterP[ path ] then return end

		filterP[ path ] = true

		table.insert( filterI, path )
	end

	-- adds a path to the filter.
	--
	-- rsync needs to have entries for all steps in the path,
	-- so the file for example d1/d2/d3/f1 needs following filters:
	-- 'd1/', 'd1/d2/', 'd1/d2/d3/' and 'd1/d2/d3/f1'
	for _, path in ipairs( paths )
	do
		if path and path ~= ''
		then
			addToFilter( path )

			local pp = string.match( path, '^(.*/)[^/]+/?' )

			while pp
			do
				addToFilter( pp )

				pp = string.match( pp, '^(.*/)[^/]+/?' )
			end
		end
	end

	log(
		'Normal',
		'Calling rsync with filter-list of new/modified files/dirs\n',
		table.concat( filterI, '\n' )
	)

	local config = inlet.getConfig( )

	local delete = nil

	if config.delete == true or config.delete == 'running'
	then
		delete = { '--delete', '--ignore-errors' }
	end

	spawn(
		elist,
		config.rsync.binary,
		'<', table.concat( filterI, '\000' ),
		config.rsync._computed,
		'-r',
		delete,
		'--force',
		'--from0',
		'--include-from=-',
		'--exclude=*',
		config.source,
		target
	)
end


--
-- Returns true for non Init and Blanket events.
--
local eventNotInitBlank =
       function
(
       event
)
       return event.etype ~= 'Init' and event.etype ~= 'Blanket'
end

--
-- Returns size or true if the event is for batch processing
--
local getBatchSize =
	function
(
	event
)
	-- print("getBatchSize", event, event.status, event.etype, event.pathname)
	if event.status == 'active' then
		return false
	end
	if event.etype == 'Init' or event.etype == 'Blanket' or event.etype == 'Full' then
		return false
	end
	-- moves and deletes go always into batch
	if event.etype == 'Move' or event.etype == 'Delete' then
		return true
	end
	return lsyncd.get_file_size(event.sourcePath)
end

--
-- Spawns rsync for a list of events
--
-- Exclusions are already handled by not having
-- events for them.
--
rsync.action = function
	(
		inlet
	)
	local sizeLimit = inlet.getConfig().batchSizeLimit

	if sizeLimit == nil then
		-- gets all events ready for syncing
		return run_action(inlet, inlet.getEvents(eventNotInitBlank))
	else
		-- spawn all files under the size limit/deletes/moves in batch mode
		local eventInBatch = function(event)
			if event.etype == "Full" then
				return false
			end
			local size = getBatchSize(event)
			if type(size) == "boolean" then
				return size
			elseif size == nil then
				return true
			end
			if size <= sizeLimit then
				return true
			end
			return false
		end

		-- indicator for grabbing one element of the queue
		local single_returned = false
		-- grab all events for seperate transfers
		local eventNoBatch = function(event)
			if event.etype == "Full" then
				return false
			end
			local size = getBatchSize(event)
			if type(size) ~= "number" or size == nil then
				return false
			end
			if single_returned then
				return 'break'
			end
			if size > sizeLimit then
				single_returned = true
				return true
			end
			return false
		end
		local extralist = inlet.getEvents(eventInBatch)

		-- get all batched events
		if extralist.size() > 0 then
			run_action(inlet, extralist)
		end

		while true do
			local cnt, maxcnt = lsyncd.get_process_info()
			if inlet.getSync().processes:size( ) >= inlet.getConfig().maxProcesses then
				log('Normal',
				'Maximum processes for sync reached. Delaying large transfer for sync: '..inlet.getConfig().name)
				break
			elseif maxcnt and cnt >= maxcnt then
			log('Normal',
				'Maximum process count reached. Delaying large transfer for sync: '..inlet.getConfig().name)
				break
			end
			local extralist = inlet.getEvents(eventNoBatch)

			-- no more single size events
			if extralist.size() == 0 then break end
			run_action(inlet, extralist)
			-- get next result
			single_returned = false
		end
	end
end

----
---- NOTE: This optimized version can be used once
----       https://bugzilla.samba.org/show_bug.cgi?id=12569
----       is fixed.
----
---- Spawns rsync for a list of events
----
---- Exclusions are already handled by not having
---- events for them.
----
--rsync.action = function
--(
--	inlet
--)
--	local config = inlet.getConfig( )
--
--	-- gets all events ready for syncing
--	local elist = inlet.getEvents( eventNotInitBlank )
--
--	-- gets the list of paths for the event list
--	-- deletes create multi match patterns
--	local paths = elist.getPaths( )
--
--	-- removes trailing slashes from dirs.
--	for k, v in ipairs( paths )
--	do
--		if string.byte( v, -1 ) == 47
--		then
--			paths[ k ] = string.sub( v, 1, -2 )
--		end
--	end
--
--	log(
--		'Normal',
--		'Calling rsync with filter-list of new/modified files/dirs\n',
--		table.concat( paths, '\n' )
--	)
--
--	local delete = nil
--
--	if config.delete == true
--	or config.delete == 'running'
--	then
--		delete = { '--delete-missing-args', '--ignore-errors' }
--	end
--
--	spawn(
--		elist,
--		config.rsync.binary,
--		'<', table.concat( paths, '\000' ),
--		config.rsync._computed,
--		delete,
--		'--force',
--		'--from0',
--		'--files-from=-',
--		config.source,
--		config.target
--	)
--end


--
-- Spawns the recursive startup sync.
--
rsync.init = function
(
	event
)
	return rsync.full(event)
end

--
-- Triggers a full sync event
--
rsync.full = function
	(
		event
	)
	local config   = event.config

	local inlet    = event.inlet

	local excludes = inlet.getExcludes( )

	local filters = inlet.hasFilters( ) and inlet.getFilters( )

	local delete   = {}

	local target   = config.target

	if not target
	then
		if not config.host
		then
			error('Internal fail, Neither target nor host is configured')
		end

		target = config.host .. ':' .. config.targetdir
	end

	local substitudes = inlet.getSubstitutionData(event, {})
	target = substitudeCommands(target, substitudes)

	if config.delete == true
	or config.delete == 'startup'
	then
		delete = { '--delete', '--ignore-errors' }
	end

	if config.rsync.delete_excluded == true
	then
		table.insert( delete, '--delete-excluded' )
	end

	if not filters and #excludes == 0
	then
		-- starts rsync without any filters or excludes
		log(
			'Normal',
			'recursive full rsync: ',
			config.source,
			' -> ',
			target
		)

		spawn(
			event,
			config.rsync.binary,
			delete,
			config.rsync._computed,
			'-r',
			config.source,
			target
		)

	elseif not filters
	then
		-- starts rsync providing an exclusion list
		-- on stdin
		local exS = table.concat( excludes, '\n' )

		log(
			'Normal',
			'recursive full rsync: ',
			config.source,
			' -> ',
			target,
			' excluding\n',
			exS
		)

		spawn(
			event,
			config.rsync.binary,
			'<', exS,
			'--exclude-from=-',
			delete,
			config.rsync._computed,
			'-r',
			config.source,
			target
		)
	else
		-- starts rsync providing a filter list
		-- on stdin
		local fS = table.concat( filters, '\n' )

		log(
			'Normal',
			'recursive full rsync: ',
			config.source,
			' -> ',
			target,
			' filtering\n',
			fS
		)

		spawn(
			event,
			config.rsync.binary,
			'<', fS,
			'--filter=. -',
			delete,
			config.rsync._computed,
			'-r',
			config.source,
			target
		)
	end
end


--
-- Prepares and checks a syncs configuration on startup.
--
rsync.prepare = function
(
	config,    -- the configuration
	level,     -- additional error level for inherited use ( by rsyncssh )
	skipTarget -- used by rsyncssh, do not check for target
)

	-- First let default.prepare test the checkgauge
	default.prepare( config, level + 6 )

	if not skipTarget and not config.target
	then
		error(
			'default.rsync needs "target" configured',
			level
		)
	end

	-- checks if the _computed argument exists already
	if config.rsync._computed
	then
		error(
			'please do not use the internal rsync._computed parameter',
			level
		)
	end

	-- computes the rsync arguments into one list
	local crsync = config.rsync;

	-- everything implied by archive = true
	local archiveFlags = {
		recursive   =  true,
		links       =  true,
		perms       =  true,
		times       =  true,
		group       =  true,
		owner       =  true,
		devices     =  true,
		specials    =  true,
		hard_links  =  false,
		acls        =  false,
		xattrs      =  false,
	}

	-- if archive is given the implications are filled in
	if crsync.archive
	then
		for k, v in pairs( archiveFlags )
		do
			if crsync[ k ] == nil
			then
				crsync[ k ] = v
			end
		end
	end

	crsync._computed = { true }

	--- @type any
	local computed = crsync._computed

	local computedN = 2

	local shortFlags = {
		acls               = 'A',
		backup             = 'b',
		checksum           = 'c',
		compress           = 'z',
		copy_dirlinks      = 'k',
		copy_links         = 'L',
		cvs_exclude        = 'C',
		dry_run            = 'n',
		executability      = 'E',
		group              = 'g',
		hard_links         = 'H',
		ignore_times       = 'I',
		ipv4               = '4',
		ipv6               = '6',
		keep_dirlinks      = 'K',
		links              = 'l',
		one_file_system    = 'x',
		omit_dir_times     = 'O',
		omit_link_times    = 'J',
		owner              = 'o',
		perms              = 'p',
		protect_args       = 's',
		prune_empty_dirs   = 'm',
		quiet              = 'q',
		sparse             = 'S',
		times              = 't',
		update             = 'u',
		verbose            = 'v',
		whole_file         = 'W',
		xattrs             = 'X',
	}

	local shorts = { '-' }
	local shortsN = 2

	if crsync._extra
	then
		for k, v in ipairs( crsync._extra )
		do
			computed[ computedN ] = v
			computedN = computedN  + 1
		end
	end

	for k, flag in pairs( shortFlags )
	do
		if crsync[ k ]
		then
			shorts[ shortsN ] = flag
			shortsN = shortsN + 1
		end
	end

	if crsync.devices and crsync.specials
	then
			shorts[ shortsN ] = 'D'
			shortsN = shortsN + 1
	else
		if crsync.devices
		then
			computed[ computedN ] = '--devices'
			computedN = computedN  + 1
		end

		if crsync.specials
		then
			computed[ computedN ] = '--specials'
			computedN = computedN  + 1
		end
	end

	if crsync.append
	then
		computed[ computedN ] = '--append'
		computedN = computedN  + 1
	end

	if crsync.append_verify
	then
		computed[ computedN ] = '--append-verify'
		computedN = computedN  + 1
	end

	if crsync.backup_dir
	then
		computed[ computedN ] = '--backup-dir=' .. crsync.backup_dir
		computedN = computedN  + 1
	end

	if crsync.bwlimit
	then
		computed[ computedN ] = '--bwlimit=' .. crsync.bwlimit
		computedN = computedN  + 1
	end

	if crsync.chmod
	then
		computed[ computedN ] = '--chmod=' .. crsync.chmod
		computedN = computedN  + 1
	end

	if crsync.chown
	then
		computed[ computedN ] = '--chown=' .. crsync.chown
		computedN = computedN  + 1
	end

	if crsync.copy_unsafe_links
	then
		computed[ computedN ] = '--copy-unsafe-links'
		computedN = computedN  + 1
	end

	if crsync.groupmap
	then
		computed[ computedN ] = '--groupmap=' .. crsync.groupmap
		computedN = computedN  + 1
	end

	if crsync.existing
	then
		computed[ computedN ] = '--existing'
		computedN = computedN  + 1
	end

	if crsync.inplace
	then
		computed[ computedN ] = '--inplace'
		computedN = computedN  + 1
	end

	if crsync.password_file
	then
		computed[ computedN ] = '--password-file=' .. crsync.password_file
		computedN = computedN  + 1
	end

	if crsync.rsh
	then
		computed[ computedN ] = '--rsh=' .. crsync.rsh
		computedN = computedN  + 1
	end

	if crsync.rsync_path
	then
		computed[ computedN ] = '--rsync-path=' .. crsync.rsync_path
		computedN = computedN  + 1
	end

	if crsync.suffix
	then
		computed[ computedN ] = '--suffix=' .. crsync.suffix
		computedN = computedN  + 1
	end

	if crsync.temp_dir
	then
		computed[ computedN ] = '--temp-dir=' .. crsync.temp_dir
		computedN = computedN  + 1
	end

	if crsync.timeout
	then
		computed[ computedN ] = '--timeout=' .. crsync.timeout
		computedN = computedN  + 1
	end

	if crsync.usermap
	then
		computed[ computedN ] = '--usermap=' .. crsync.usermap
		computedN = computedN  + 1
	end

	if shortsN ~= 2
	then
		computed[ 1 ] = table.concat( shorts, '' )
	else
		computed[ 1 ] = { }
	end

	-- appends a / to target if not present
	-- and not a ':' for home dir.
	if not skipTarget
	and string.sub( config.target, -1 ) ~= '/'
	and string.sub( config.target, -1 ) ~= ':'
	then
		config.target = config.target..'/'
	end
end


--
-- By default do deletes.
--
rsync.delete = true

--
-- Rsyncd exitcodes
--
rsync.exitcodes  = default.rsyncExitCodes

--
-- Calls rsync with this default options
--
rsync.rsync =
{
	-- The rsync binary to be called.
	binary        = 'rsync',
	links         = true,
	times         = true,
	protect_args  = true
}


--
-- Default delay
--
rsync.delay = 15



if not default
then
	error( 'default not loaded' );
end

if not default.rsync
then
	error( 'default.rsync not loaded' );
end

if default.rsyncssh
then
	error( 'default-rsyncssh already loaded' );
end

--
-- rsyncssh extends default.rsync
--
local rsyncssh = { default.rsync }

default.rsyncssh = rsyncssh

--
-- used to ensure there aren't typos in the keys
--
rsyncssh.checkgauge = {

	-- unsets the inherited value of from default.rsync
	target          =  false,
	onMove          =  true,

	-- rsyncssh users host and targetdir
	host            =  true,
	targetdir       =  true,
	sshExitCodes    =  true,
	rsyncExitCodes  =  true,

	-- ssh settings
	ssh = {
		binary       =  true,
		identityFile =  true,
		options      =  true,
		port         =  true,
		_extra       =  true
	},
}


--
-- Returns true for non Init, Blanket and Move events.
--
local eventNotInitBlankMove =
	function
(
	event
)
	-- TODO use a table
	if event.etype == 'Move'
	or event.etype == 'Init'
	or event.etype == 'Blanket'
	then
		return 'break'
	else
		return true
	end
end


--
-- Replaces what rsync would consider filter rules by literals.
--
local replaceRsyncFilter =
	function
(
	path
)
	if not path then return end

	return(
		path
		:gsub( '%?', '\\?' )
		:gsub( '%*', '\\*' )
		:gsub( '%[', '\\[' )
	)
end


--
-- Spawns rsync for a list of events
--
rsyncssh.action = function
(
	inlet
)
	local config = inlet.getConfig( )

	local event, event2 = inlet.getEvent( )

	-- makes move local on target host
	-- if the move fails, it deletes the source
	if event.etype == 'Move'
	then
		local path1 = config.targetdir .. event.path

		local path2 = config.targetdir .. event2.path

		path1 = "'" .. path1:gsub ('\'', '\'"\'"\'') .. "'"
		path2 = "'" .. path2:gsub ('\'', '\'"\'"\'') .. "'"

		log(
			'Normal',
			'Moving ',
			event.path,
			' -> ',
			event2.path
		)

		spawn(
			event,
			config.ssh.binary,
			config.ssh._computed,
			config.host,
			'mv',
			path1,
			path2,
			'||', 'rm', '-rf',
			path1
		)

		return
	end

	-- otherwise a rsync is spawned
	local elist = inlet.getEvents( eventNotInitBlankMove )

	-- gets the list of paths for the event list
	-- deletes create multi match patterns
	local paths = elist.getPaths( )

	--
	-- Replaces what rsync would consider filter rules by literals
	--
	local function sub( p )
		if not p then return end

		return p:
			gsub( '%?', '\\?' ):
			gsub( '%*', '\\*' ):
			gsub( '%[', '\\[' ):
			gsub( '%]', '\\]' )
	end

	--
	-- Gets the list of paths for the event list
	--
	-- Deletes create multi match patterns
	--
	local paths = elist.getPaths(
		function( etype, path1, path2 )
			if string.byte( path1, -1 ) == 47 and etype == 'Delete' then
				return sub( path1 )..'***', sub( path2 )
			else
				return sub( path1 ), sub( path2 )
			end
		end
	)

	-- stores all filters by integer index
	local filterI = { }

	-- stores all filters with path index
	local filterP = { }

	-- adds one path to the filter
	local function addToFilter( path )
		if filterP[ path ] then return end

		filterP[ path ] = true

		table.insert( filterI, path )
	end

	-- adds a path to the filter.
	--
	-- rsync needs to have entries for all steps in the path,
	-- so the file for example d1/d2/d3/f1 needs following filters:
	-- 'd1/', 'd1/d2/', 'd1/d2/d3/' and 'd1/d2/d3/f1'
	for _, path in ipairs( paths )
	do
		if path and path ~= ''
		then
			addToFilter(path)

			local pp = string.match( path, '^(.*/)[^/]+/?' )

			while pp
			do
				addToFilter(pp)
				pp = string.match( pp, '^(.*/)[^/]+/?' )
			end

		end

	end

	log(
		'Normal',
		'Calling rsync with filter-list of new/modified files/dirs\n',
		table.concat( filterI, '\n' )
	)

	local config = inlet.getConfig( )

	local delete = nil

	if config.delete == true or config.delete == 'running'
	then
		delete = { '--delete', '--ignore-errors' }
	end

	spawn(
		elist,
		config.rsync.binary,
		'<', table.concat( filterI, '\000' ),
		config.rsync._computed,
		'-r',
		delete,
		'--force',
		'--from0',
		'--include-from=-',
		'--exclude=*',
		config.source,
		config.host .. ':' .. config.targetdir
	)
end


----
---- NOTE: This optimized version can be used once
----       https://bugzilla.samba.org/show_bug.cgi?id=12569
----       is fixed.
----
--
-- Spawns rsync for a list of events
--
--rsyncssh.action = function
--(
--	inlet
--)
--	local config = inlet.getConfig( )
--
--	local event, event2 = inlet.getEvent( )
--
--	-- makes move local on target host
--	-- if the move fails, it deletes the source
--	if event.etype == 'Move'
--	then
--		local path1 = config.targetdir .. event.path
--
--		local path2 = config.targetdir .. event2.path
--
--		path1 = "'" .. path1:gsub ('\'', '\'"\'"\'') .. "'"
--		path2 = "'" .. path2:gsub ('\'', '\'"\'"\'') .. "'"
--
--		log(
--			'Normal',
--			'Moving ',
--			event.path,
--			' -> ',
--			event2.path
--		)
--
--		spawn(
--			event,
--			config.ssh.binary,
--			config.ssh._computed,
--			config.host,
--			'mv',
--			path1,
--			path2,
--			'||', 'rm', '-rf',
--			path1
--		)
--
--		return
--	end
--
--	-- otherwise a rsync is spawned
--	local elist = inlet.getEvents( eventNotInitBlankMove )
--
--	-- gets the list of paths for the event list
--	-- deletes create multi match patterns
--	local paths = elist.getPaths( )
--
--	-- removes trailing slashes from dirs.
--	for k, v in ipairs( paths )
--	do
--		if string.byte( v, -1 ) == 47
--		then
--			paths[ k ] = string.sub( v, 1, -2 )
--		end
--	end
--
--	log(
--		'Normal',
--		'Rsyncing list\n',
--		table.concat( paths, '\n' )
--	)
--
--	local delete = nil
--
--	if config.delete == true
--	or config.delete == 'running'
--	then
--		delete = { '--delete-missing-args', '--ignore-errors' }
--	end
--
--	spawn(
--		elist,
--		config.rsync.binary,
--		'<', table.concat( paths, '\000' ),
--		config.rsync._computed,
--		delete,
--		'--force',
--		'--from0',
--		'--files-from=-',
--		config.source,
--		config.host .. ':' .. config.targetdir
--	)
--end


--
-- Called when collecting a finished child process
--
rsyncssh.collect = function
(
	agent,
	exitcode
)
	local config = agent.config

	if not agent.isList and agent.etype == 'Init'
	then
		local rc = config.rsyncExitCodes[exitcode]

		if rc == 'ok'
		then
			log( 'Normal', 'Startup of "', agent.source, '" finished: ', exitcode )
		elseif rc == 'again'
		then
			if settings('insist')
			then
				log( 'Normal', 'Retrying startup of "', agent.source, '": ', exitcode )
			else
				log(
					'Error',
					'Temporary or permanent failure on startup of "',
					agent.source, '". Terminating since "insist" is not set.'
				)

				terminate( -1 ) -- ERRNO
			end
		elseif rc == 'die'
		then
			log( 'Error', 'Failure on startup of "', agent.source, '": ', exitcode )
		else
			log( 'Error', 'Unknown exitcode on startup of "', agent.source, ': "', exitcode )

			rc = 'die'
		end

		return rc
	end

	if agent.isList
	then
		local rc = config.rsyncExitCodes[ exitcode ]

		if rc == 'ok'
		then
			log( 'Normal', 'Finished (list): ', exitcode )
		elseif rc == 'again'
		then
			log( 'Normal', 'Retrying (list): ', exitcode )
		elseif rc == 'die'
		then
			log( 'Error',  'Failure (list): ', exitcode )
		else
			log( 'Error', 'Unknown exitcode (list): ', exitcode )

			rc = 'die'
		end
		return rc
	else
		local rc = config.sshExitCodes[exitcode]

		if rc == 'ok'
		then
			log( 'Normal', 'Finished ', agent.etype,' ', agent.sourcePath, ': ', exitcode )
		elseif rc == 'again'
		then
			log( 'Normal', 'Retrying ', agent.etype, ' ', agent.sourcePath, ': ', exitcode )
		elseif rc == 'die'
		then
			log( 'Normal', 'Failure ', agent.etype, ' ', agent.sourcePath, ': ', exitcode )
		else
			log( 'Error', 'Unknown exitcode ', agent.etype,' ', agent.sourcePath,': ', exitcode )

			rc = 'die'
		end

		return rc
	end

end

--
-- checks the configuration.
--
rsyncssh.prepare = function
(
	config,
	level
)
	default.rsync.prepare( config, level + 1, true )

	if not config.host
	then
		error( 'default.rsyncssh needs "host" configured', level )
	end

	if not config.targetdir
	then
		error( 'default.rsyncssh needs "targetdir" configured', level )
	end

	--
	-- computes the ssh options
	--
	if config.ssh._computed
	then
		error( 'please do not use the internal rsync._computed parameter', level )
	end

	if config.maxProcesses ~= 1
	then
		error( 'default.rsyncssh must have maxProcesses set to 1.', level )
	end

	local cssh = config.ssh;

	cssh._computed = { }

	local computed = cssh._computed

	local computedN = 1

	local rsyncc = config.rsync._computed

	if cssh.identityFile
	then
		computed[ computedN ] = '-i'

		computed[ computedN + 1 ] = cssh.identityFile

		computedN = computedN + 2

		if not config.rsync._rshIndex
		then
			config.rsync._rshIndex = #rsyncc + 1

			rsyncc[ config.rsync._rshIndex ] = '--rsh=ssh'
		end

		rsyncc[ config.rsync._rshIndex ] =
			rsyncc[ config.rsync._rshIndex ] ..
			' -i ' ..
			cssh.identityFile
	end

	if cssh.options
	then
		for k, v in pairs( cssh.options )
		do
			computed[ computedN ] = '-o'

			computed[ computedN + 1 ] = k .. '=' .. v

			computedN = computedN + 2

			if not config.rsync._rshIndex
			then
				config.rsync._rshIndex = #rsyncc + 1

				rsyncc[ config.rsync._rshIndex ] = '--rsh=ssh'
			end

			rsyncc[ config.rsync._rshIndex ] =
				table.concat(
					{
						rsyncc[ config.rsync._rshIndex ],
						' -o ',
						k,
						'=',
						v
					},
					''
				)
		end
	end

	if cssh.port
	then
		computed[ computedN ] = '-p'

		computed[ computedN + 1 ] = cssh.port

		computedN = computedN + 2

		if not config.rsync._rshIndex
		then
			config.rsync._rshIndex = #rsyncc + 1

			rsyncc[ config.rsync._rshIndex ] = '--rsh=ssh'
		end

		rsyncc[ config.rsync._rshIndex ] =
			rsyncc[ config.rsync._rshIndex ] .. ' -p ' .. cssh.port
	end

	if cssh._extra
	then
		for k, v in ipairs( cssh._extra )
		do
			computed[ computedN ] = v

			computedN = computedN  + 1

            if not config.rsync._rshIndex
		    then
			    config.rsync._rshIndex = #rsyncc + 1

			    rsyncc[ config.rsync._rshIndex ] = '--rsh=ssh'
		    end

		    rsyncc[ config.rsync._rshIndex ] =
			    rsyncc[ config.rsync._rshIndex ] .. ' ' .. v

		end
	end

	-- appends a slash to the targetdir if missing
	-- and is not ':' for home dir
	if string.sub( config.targetdir, -1 ) ~= '/'
	and string.sub( config.targetdir, -1 ) ~= ':'
	then
		config.targetdir = config.targetdir .. '/'
	end

end

--
-- allow processes
--
rsyncssh.maxProcesses = 1

--
-- The core should not split move events
--
rsyncssh.onMove = true

--
-- default delay
--
rsyncssh.delay = 15


--
-- no default exit codes
--
rsyncssh.exitcodes = false

--
-- rsync exit codes
--
rsyncssh.rsyncExitCodes = default.rsyncExitCodes

--
-- ssh exit codes
--
rsyncssh.sshExitCodes = default.sshExitCodes


--
-- ssh calls configuration
--
-- ssh is used to move and delete files on the target host
--
rsyncssh.ssh = {

	--
	-- the binary called
	--
	binary = 'ssh',

	--
	-- if set adds this key to ssh
	--
	identityFile = nil,

	--
	-- if set adds this special options to ssh
	--
	options = nil,

	--
	-- if set connect to this port
	--
	port = nil,

	--
	-- extra parameters
	--
	_extra = { }
}



if not default then
	error('default not loaded')
end

if not default.rsync then
	error('default-direct (currently) needs default.rsync loaded')
end

if default.direct then
	error('default-direct already loaded')
end

local direct = { }

default.direct = direct


--
-- known configuration parameters
--
direct.checkgauge = {
	--
	-- inherits rsync config params
	--
	default.rsync.checkgauge,

	rsyncExitCodes  =  true,
	onMove          =  true,
}


--
-- Spawns rsync for a list of events
--
direct.action = function(inlet)
	-- gets all events ready for syncing
	local event, event2 = inlet.getEvent()
	local config = inlet.getConfig()

	if event.etype == 'Create' then
		if event.isdir then
			spawn(
				event,
				'mkdir',
				'--',
				event.targetPath
			)
		else
			-- 'cp -t', not supported on OSX
			spawn(
				event,
				'cp',
				'-p',
				'--',
				event.sourcePath,
				event.targetPathdir
			)
		end
	elseif event.etype == 'Modify' then
		if event.isdir then
			error("Do not know how to handle 'Modify' on dirs")
		end
		spawn(event,
			'cp',
			'-p',
			'--',
			event.sourcePath,
			event.targetPathdir
		)
	elseif event.etype == 'Delete' then

		if
			config.delete ~= true and
			config.delete ~= 'running'
		then
			inlet.discardEvent(event)
			return
		end

		local tp = event.targetPath

		-- extra security check
		if tp == '' or tp == '/' or not tp then
			error('Refusing to erase your harddisk!')
		end

		spawn(event, 'rm', '-rf', '--', tp)

	elseif event.etype == 'Move' then
		local tp = event.targetPath

		-- extra security check
		if tp == '' or tp == '/' or not tp then
			error('Refusing to erase your harddisk!')
		end

		local command = 'mv -- "$1" "$2" || rm -rf -- "$1"'

		if
			config.delete ~= true and
			config.delete ~= 'running'
		then
			command = 'mv -- "$1" "$2"'
		end

		spawnShell(
			event,
			command,
			event.targetPath,
			event2.targetPath
		)
	elseif event.etype == 'Full' then
		local tp = event.targetPath

		-- extra security check
		if tp == '' or tp == '/' or not tp then
			error('Refusing to erase your harddisk!')
		end

		-- trigger full sync function
		direct.full(event)
	else
		log('Warn', 'ignored an event of type "',event.etype, '"')
		inlet.discardEvent(event)
	end
end

--
-- Called when collecting a finished child process
--
direct.collect = function(agent, exitcode)

	local config = agent.config

	if not agent.isList and agent.etype == 'Init' then
		local rc = config.rsyncExitCodes[exitcode]
		if rc == 'ok' then
			log('Normal', 'Startup of "',agent.source,'" finished: ', exitcode)
		elseif rc == 'again'
		then
			if settings( 'insist' )
			then
				log('Normal', 'Retrying startup of "',agent.source,'": ', exitcode)
			else
				log('Error', 'Temporary or permanent failure on startup of "',
				agent.source, '". Terminating since "insist" is not set.');
				terminate(-1) -- ERRNO
			end
		elseif rc == 'die' then
			log('Error', 'Failure on startup of "',agent.source,'": ', exitcode)
		else
			log('Error', 'Unknown exitcode on startup of "', agent.source,': "',exitcode)
			rc = 'die'
		end
		return rc
	end

	-- everything else is just as it is,
	-- there is no network to retry something.
	return
end

--
-- Spawns the recursive startup sync
-- (currently) identical to default rsync.
--
direct.init = default.rsync.init

--
-- Spawns the recursive startup sync
-- (currently) identical to default rsync.
--
direct.full = default.rsync.full

--
-- Checks the configuration.
--
direct.prepare = function( config, level )

	default.rsync.prepare( config, level + 1 )

end

--
-- Default delay is very short.
--
direct.delay = 1

--
-- Let the core not split move events.
--
direct.onMove = true

--
-- Rsync configuration for startup.
--
direct.rsync = default.rsync.rsync
direct.rsyncExitCodes = default.rsyncExitCodes

--
-- By default do deletes.
--
direct.delete = true

--
-- On many system multiple disk operations just rather slow down
-- than speed up.

direct.maxProcesses = 1
