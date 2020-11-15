" vim-tasks {{{
function! ParseBashCommand(...) " {{{
	let choice = a:1
	let parent = a:2
	let cmd_arr = []
	if has_key(choice, "deps")
		for l in choice["deps"]
			for item in parent
				if has_key(item, "label")
							\ && item["label"] == l
							\	&& has_key(item, "type")
							\	&& item["type"] == "bash"
					let cmd_arr = cmd_arr + ParseBashCommand(item, parent)
				endif
			endfor
		endfor
	endif

	if has_key(choice, "action")
		let cmd_arr = cmd_arr + [choice["action"]]
	endif

	return cmd_arr
endfunction " }}}
function! HandleFinalChoice(...) " {{{
	let choice = a:1
	let parent_dict = a:2

	if choice["type"] == "bash"
		let cmd_arr = ParseBashCommand(choice, parent_dict)
		let dlim = ""
		let command = ""
		for cmd in cmd_arr
			let command = command.dlim.cmd
			let dlim = " && "
		endfor

		exec "!".command
	else
		echo "not found"
	endif
endfunction " }}}
function! ChoiceFromMap(...) " {{{
	let ret_val = a:1
	let task_key_map = {}
	let translate_map = {}

	let ret_val_keys = []
	for item in ret_val
		let key = item["label"]
		let ret_val_keys = ret_val_keys + [key]
	endfor

	let ret_val_keys = sort(ret_val_keys)

	for i in ret_val_keys
		let k = i
		let v = ret_val[i]
		let h = 0
		for j in split(k, '\zs')
			let c = tolower(j)
			if !has_key(task_key_map, c)
				let task_key_map[c] = k
				if h == 0
					let s = '&'.k
					let translate_map[s] = k
				else
					let start = k[0:h-1]
					let end = k[h:]
					let s = start.'&'.end
					let translate_map[s] = k
				endif
				break
			endif
			let h = h + 1
		endfor
	endfor

	let task_array = []
	for i in items(translate_map)
		let task_array = task_array + [i[0]]
	endfor
	let task_array = sort(task_array)

	let task_string = ""
	let delim = ""
	for i in task_array
		let task_string = task_string.delim.i
		let delim = "\n"
	endfor

	let choice = confirm(a:2, task_string)
	let choice = choice - 1

	if choice > -1
		let t_value = task_array[choice]
		let value = translate_map[t_value]
		let orig_val = ret_val[value]

		let picked = {}
		for item in ret_val
			if item["label"] == value
				let picked = item
			endif
		endfor

		let has_type = has_key(picked, "type")
		if has_type && picked["type"] != "directory"
			call HandleFinalChoice(picked, ret_val)
			return
		else
			call ChoiceFromMap(picked["items"], value.":")
		endif
	else
		return
	endif
endfunction " }}}
function! ParseTaskMap(...) " {{{
	let ret_dict = a:1
	let has_type = has_key(ret_dict, 'type')
	if has_type
		let type = ret_dict["type"]
		if type == "directory"
			call ChoiceFromMap(ret_dict["items"])
		else
			return
		endif
	else
		call ChoiceFromMap(ret_dict["tasks"], "Run Which:")
	endif
endfunction " }}}
function! AggregateTaskMaps(...) " {{{
	let def_tasks = a:1
	let proj_tasks = a:2

	let has_def = 0
	if len(items(def_tasks)) > 0
		let has_def = 1
	endif

	let has_proj = 0
	if len(items(proj_tasks)) > 0
		let has_proj = 1
	endif

	let has_both = has_proj + has_def

	if has_both == 2
		let def_tasks["tasks"] = def_tasks["tasks"] + proj_tasks["tasks"]
		return def_tasks
	elseif has_proj == 1
		return proj_tasks
	elseif has_def == 1
		return def_tasks
	else
		return {}
	endif
endfunction " }}}
function! RunVimTasks() " {{{
	let path = fnamemodify('.', ':p')
	let file = path.'.tasks.vim.json'

	let homefile = $HOME.'/.tasks.vim.json'

	let is_home = 0
	if file == homefile
		let is_home = 1
	end

	let def_tasks = {}
	if is_home != 1
		if filereadable(homefile)
			let f = readfile(homefile)
			let txt = join(f, '')
			let def_tasks = ParseJSON(txt)
		endif
	endif

	if filereadable(file)
		let proj_file = readfile(file)
		let txt = join(proj_file, '')
		let proj_tasks = ParseJSON(txt)
		if is_home != 1
			let g:proj_tasks = AggregateTaskMaps(def_tasks, proj_tasks)
		else
			let g:proj_tasks = proj_tasks
		endif

		call ParseTaskMap(g:proj_tasks, "Run Task:")
	else
		let prompt = 'project .tasks.vim.json not found. Create?'
		let choices = "&Yes\n&No"
		let i = confirm(prompt, choices)
		if i == 1
			if is_home == 1
				exec "! echo 'let g:default_tasks_map = {}' > ".file
			else
				exec "! echo 'let g:tasks_map = {}' > ".file
			endif
		endif
	endif
endfunction " }}}
" }}}
" VIm Folding {{{
" vim:fdm=marker
" }}}
