import requests
import urllib2

# Simple hacky api to stackoverflow

class ShittyAPI:
    def __init__(self):
	self.url = "http://api.stackexchange.com/2.2"
	self.site = "stackoverflow"

    def get_questions(self, search_term):
	""" Simply grabs the questions from StackOverflow with search_term in the title """
	encoded_term = urllib2.quote(search_term)
	req_url = '%s/search?order=desc&sort=votes&site=%s&intitle=%s' % (self.url, self.site, encoded_term)
	req = requests.get(req_url)
	return req.text




