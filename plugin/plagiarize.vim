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

      wanted_infoi.append({'question_id':question['question_id'],
			  'title':question['title'],
			  'body':question['body'],
			  'answer_count':question['answer_count'],
			  'link':question['link'],
			  'accepted_answer_id':accepted_answer,
			  'score':question['score']
			  }
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
      wanted_info.append({'answer': answer['answer_id'],
			 'body': answer['body'],
			 'score': answer['score'],
			 'is_accepted': answer['is_accepted']
			 }
    self.answers = wanted_info

  def get_question(self, question_id):
    """ Just grabs the text of the given question id """
    return self.questions[question_id]['body']


  def get_answer(self, answer_id):
    return self.answers[answer_id]['body']

def prepare_titles(question_list):
  """ Takes a bunch of questions and prepares the titles for display in inputlist """
  formatstr = "'%d. %s || Score: %d || #Answers: %d || Accepted Answer: %r'"
  return [formatstr % (ind, i['title'], i['score'], i['answer_count'], (i['accepted_answer_id'] != None)) for ind, i in enumerate(question_list)]

def display_questions(shitty_api_obj, line_offset):
  """ Function that will manage interacting with the user on displaying and
  asking for questions """
  # shitty_api_obj should be pre-loaded with the question list sorted however
  this_slice = shitty_api_obj.sorted_questions[line_offset:LINES]
  choices_str = "[" + ",".join(prepare_titles(this_slice)) + ("'%d. More','%d. Nah quit']" % (LINES, LINES+1))
  choice_made = int(vim.eval("inputlist(" + choices_str + ")")) # fuck me
  # Three cases now:
  # choice_made == LINES: increment line_offset by LINES, call this function again
  if choice_made == LINES:
    display_questions(shitty_api_obj, line_offset + LINES)
  # or the user is like nah
  elif choice_made == LINES + 1:
    return
  # or actually we want one of them god forbid
  elif choice_made >= 0 and choice_made < LINES:
    retcode = display_question(this_slice[choice_made]) # this will display the specific question and prompt the user for all sorts of stuff...
    if retcode == 0:
      return
    display_questions(shitty_api_obj, line_offset) # this will redo this function if the user doesn't quite like that

def display_question(question):
  """ Displays a confirm dialog asking whether or not a user wants that
  question's answer displayed """
  display_text = question['body']
  if question['accepted_answer_id'] != None:
    acc = 1
    choices = "&Accepted Answer\n&See Answers\nGo &Back"
  else:
    acc = 0
    choices = "&See Answers\nGo &Back"
  option_chosen = int(vim.eval("(%s, %s, 1)" % (display_text, choices)))
  if option_chosen == 0:
    # User wants to leave
    return 0
  elif option_chosen == 1 and acc == 1:
    # User just wants to see the accepted answers
  elif option_chosen == 1 + acc:
    # User wants to investigate this question's answers
  elif option_chosen == 2 + acc:
    return



  


  
so = ShittyAPI()
endpython

function! SOSearch(search_text)
python << endpython

search_text = vim.eval("a:search_text")
so.get_questions(search_text)
# Now compile the string of options for inputlist, but limit it to 10 (sorted by votes)
so.sorted_questions = sorted(so.questions.values(), key=lambda x: x['score'])
# Now we do the fun thing of displaying a dialog with the question text, basically asking if they want that one or not.
display_questions(so, 0)

endpython
endfunction!
