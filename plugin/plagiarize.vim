" Vim plugin for searching StackOverflow for code snippets and inserting them
" into your code

python << endpython
import random
import vim
import requests
import urllib2
import json

# Simple hacky api to stackoverflow
LINES = 10
wasted_lines = 0

class ShittyAPI:
  def __init__(self):
    self.url = "http://api.stackexchange.com/2.2"
    self.site = "stackoverflow"
    self.questions = None
    self.answers = None

  def get_questions(self, search_term):
    """ Simply grabs the questions from StackOverflow with search_term in the title """
    encoded_term = urllib2.quote(search_term)
    req_url = '%s/search?order=desc&sort=votes&filter=withbody&site=%s&intitle=%s' % (self.url, self.site, encoded_term)
    req = requests.get(req_url)
    parsed_req = json.loads(req.text)
    # We care about the following in each question
    # title
    # answer_count
    # link (for opening in external browser)
    # question_id
    # accepted_answer_id
    wanted_info = []
    for question in parsed_req['items']:
      try:
	accepted_answer = question['accepted_answer_id']
      except KeyError:
	accepted_answer = None

      wanted_info.append({'question_id':question['question_id'],
			  'title':question['title'],
			  'body':question['body'],
			  'answer_count':question['answer_count'],
			  'link':question['link'],
			  'accepted_answer_id':accepted_answer,
			  'score':question['score']
			  })
    self.questions = wanted_info



  def get_answers(self, question_id):
    """ Simply grabs the answers for a given question id """
    req_url = '%s/questions/%s/answers?site=%s&sort=votes&filter=withbody' % (self.url, question_id, self.site)
    req = requests.get(req_url)
    parsed_req = json.loads(req.text)
    # For each answer we want the following
    # body
    # score (i.e. votes)
    # is_accepted
    # answer_id
    wanted_info = []
    for answer in parsed_req['items']:
      wanted_info.append({'answer_id': answer['answer_id'],
			 'body': answer['body'],
			 'score': answer['score'],
			 'is_accepted': answer['is_accepted']
			 })
    self.answers = wanted_info

  def get_question(self, question_id):
    """ Just grabs the text of the given question id """
    return self.questions[question_id]['body']


  def get_answer(self, answer_id):
    print type(answer_id)
    req_url = '%s/answers/%d?site=%s&filter=withbody' % (self.url, answer_id, self.site)
    req = requests.get(req_url)
    parsed_req = json.loads(req.text)
    return parsed_req['items'][0]['body']

def clean_string(string):
  return string.replace("\"","\'").replace("\'","\'\'")

def prepare_titles(question_list):
  """ Takes a bunch of questions and prepares the titles for display in inputlist """
  formatstr = "'%d. %s || Score: %d || #Answers: %d || Accepted Answer: %r'"
  prepared =  [formatstr % (ind, clean_string(i['title']), i['score'], i['answer_count'], (i['accepted_answer_id'] != None)) for ind, i in enumerate(question_list[:-2])]
  prepared.append(question_list[-2])
  prepared.append(question_list[-1])
  return prepared

def prepare_answers(answer_list):
  """ Takes a bunch of answers and prepares them for display in inputlist """
  formatstr = "'%d. Score: %d || \"%s\" || Accepted? %r'"
  max_len = 80 # arbitrary character limit, will also replace the last three characters of this '...'
  try:
    prepared = [formatstr % (ind, i['score'], clean_string(i['body'][:max_len-3] + '...'), i['is_accepted']) for ind, i in enumerate(answer_list[:-1])]
    prepared.append(answer_list[-1])
    return prepared
  except TypeError:
    print answer_list
  

def display_questions(shitty_api_obj, line_offset):
  """ Function that will manage interacting with the user on displaying and
  asking for questions """
  # shitty_api_obj should be pre-loaded with the question list sorted however
  this_slice = shitty_api_obj.sorted_questions[line_offset:line_offset + LINES]
  this_slice.append("\"%d. More\"" % LINES)
  this_slice.append("\"%d. Nah quit\"" % (LINES+1))
  choices_str = "[" + ",".join(prepare_titles(this_slice)) + "]"
  choice_made = int(vim.eval("inputlist(" + choices_str + ")")) # fuck me
  # Three cases now:
  # choice_made == LINES: increment line_offset by LINES, call this function again
  if choice_made == len(this_slice) - 2:
    return display_questions(shitty_api_obj, line_offset + LINES)
  # or the user is like nah
  elif choice_made == len(this_slice) - 1:
    return
  # or actually we want one of them god forbid
  elif choice_made >= 0 and choice_made < LINES:
    retcode = display_question(shitty_api_obj, this_slice[choice_made]) # this will display the specific question and prompt the user for all sorts of stuff...
    if retcode == 0:
      return
    display_questions(shitty_api_obj, line_offset) # this will redo this function if the user doesn't quite like that

def display_question(shitty_api_obj, question):
  """ Displays a confirm dialog asking whether or not a user wants that
  question's answer displayed """
  display_text = question['body']
  if question['accepted_answer_id'] != None:
    acc = 1
    choices = "&Accepted Answer\n&See Answers\nGo &Back"
  else:
    acc = 0
    choices = "&See Answers\nGo &Back"
  option_chosen = int(vim.eval("confirm('%s', '%s', 1)" % (clean_string(display_text), choices)))
  if option_chosen == 0:
    # User wants to leave
    return 0
  elif option_chosen == 1 and acc == 1:
    # User just wants to see the accepted answers
    answer_text = shitty_api_obj.get_answer(question['accepted_answer_id'])
    # the api object can be dropped at this point because we're basically at the final stage
    retcode = display_answer(answer_text) 
  elif option_chosen == 1 + acc:
    # User wants to investigate this question's answers
    shitty_api_obj.get_answers(question['question_id'])
    shitty_api_obj.sorted_answers = sorted(shitty_api_obj.answers, key=lambda x: x['score'])
    retcode = display_answers(shitty_api_obj)
  elif option_chosen == 2 + acc:
    return
  return retcode

def display_answers(shitty_api_obj):
  """ Displays a list of answers for a question """
  this_slice = shitty_api_obj.sorted_answers[:LINES] # this will always just be from 0, any more than 10 answers down probably isn't worth it
  this_slice.append("\"%d. Nah quit\"" % LINES)
  choices_str = "[" + ",".join(prepare_answers(this_slice)) + "]"
  choice_made = int(vim.eval("inputlist(" + choices_str + ")")) # fuck me
  if choice_made == len(this_slice):
    return
  elif choice_made >= 0 and choice_made < LINES:
    retcode = display_answer(this_slice[choice_made]['body'])
  return retcode

def display_answer(answer_text):
  """ Displays an answer with a confirm dialog for copying into a register or
  exiting """
  choices = "&Copy\n&Go Back"
  choice = int(vim.eval("confirm(\"'%s'\", \"'%s'\", 1)" % (clean_string(answer_text), choices)))
  if choice == 0:
    return 0
  elif choice == 2:
    return 1
  elif choice == 1:
    # Copy it into the registers
    vim.command( "let @%s=\"'%s'\"" % ('r', clean_string(answer_text) ))
    print "Answer is available in register r"
    return 0
    
  
so = ShittyAPI()
endpython

function! SOSearch(search_text)
python << endpython

search_text = vim.eval("a:search_text")
so.get_questions(search_text)
# Now compile the string of options for inputlist, but limit it to 10 (sorted by votes)
so.sorted_questions = sorted(so.questions, key=lambda x: x['score'])
# Now we do the fun thing of displaying a dialog with the question text, basically asking if they want that one or not.
display_questions(so, 0)

endpython
endfunction!
