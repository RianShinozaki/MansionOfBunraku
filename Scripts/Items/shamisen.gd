extends Node

var note_sequence = []

func append_note(note):
	note_sequence.append(note)
	if note_sequence.size() > 4:
		note_sequence.pop_front()
	
	print(note_sequence)
	
	# if near a password puzzle:
		# if puzzle has get_password():
			# if note_sequence == puzzle.get_password():
				# PUZZLE.unlock()
