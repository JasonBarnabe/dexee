require 'dexee/mailer'

module Dexee
	class GenericMailer < ActionMailer::Base
		include Dexee::Mailer

		def dexee_email(to, from, cc, subject, body, atts, user)
			atts.each do |att|
				attachments[att[:name]] = {:mime_type => att[:mime_type], :content => att[:content]}
			end
			mail(:to => to, :from => from, :cc => cc, :subject => subject, :body => body)
		end
	end
end
