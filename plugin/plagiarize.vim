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
    wanted_info = dict()
    for question in parsed_req['items']:
      try:
	accepted_answer = question['accepted_answer_id']
      except KeyError:
	accepted_answer = None

      wanted_info[question['question_id']] = {'title':question['title'],
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
    wanted_info = dict()
    for answer in parsed_req['items']:
      wanted_info[answer['answer_id']] = {'body': answer['body'],
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

  
so = ShittyAPI()
endpython

function! SOSearch(search_text)
python << endpython

search_text = vim.eval("a:search_text")
so.get_questions(search_text)
# Now compile the string of options for inputlist, but limit it to 10 (sorted by votes)
sorted_q = sorted(so.questions.values(), key=lambda x: x['score'])
choices = prepare_titles(sorted_q[wasted_lines:wasted_lines+LINES]) # get from wasted_lines to LINES possible questions
# Now turn choices into a vim list
choices_str = "[" + ",".join(choices) + "]"
choice_made = vim.eval("inputlist(" + choices_str + ")") # jesus christ

endpython
endfunction!
