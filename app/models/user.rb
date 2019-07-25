
class User < ApplicationRecord
	attr_accessor :activation_token, :remember_token, :reset_token
	#Has_secure_passwords Adds methods to set and authenticate  a password with  BCrypt password
	has_secure_password 
	before_save :downcase_email	
	before_create :create_activation_hash

	#validations of user attributes

	validates :first_name, :last_name,:gender, presence: true, length:{maximum: 20}
	validates :user_name, presence: true,  allow_nil: true, length: {maximum: 20}

	#only letter regex
	NAME_REGEX = /\A[a-zA-Z]+\z/
	validates :first_name, :last_name, format: {with: NAME_REGEX, message: "Only allows letters"}

	# simple email regex
	EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
	validates :email ,length: {maximum: 250}, uniqueness: {case_sensitive: false}, format: {with: EMAIL_REGEX, message: "Only allows valid emails"}, presence: true
	
	#male or female regex
	GENDER_REGEX = /\A(fe)*male\z/i
	validates :gender, format: {with: GENDER_REGEX, message: "Should be either female or male" }
	validates :birthday, presence: true
	validate :birthdate_cannot_be_before_1900
	validates :password, presence: true,  allow_nil: true, length: {in: 6..15}

	#association with the posts model
	has_many :posts, dependent: :destroy

    #association with the relationship model, but as the active(requester) and the other user as the pasive(receiver)
	has_many :requested_relationships, class_name: "Relationship", foreign_key: "friend_active_id", dependent: :destroy
    has_many :requested_friends, through: :requested_relationships, source: :friend_pasive

    #association with the relationship model, but as the pasive(receiver) and the other user as the active(requester) 
    has_many :received_relationships, class_name: "Relationship", foreign_key: "friend_pasive_id", dependent: :destroy
    has_many :received_friends, through: :received_relationships, source: :friend_active

	# method made for birthday validation

	def birthdate_cannot_be_before_1900
		if birthday && birthday < Date.parse('1899-12-31')
			errors.add(:birthday, "invalid date")
		end
	end

	#Sends activation email after creation

	def send_activation_email
		UserMailer.account_activation(self).deliver_now
	end

	#Sends email to reset password


	def send_reset_email
		UserMailer.reset_password(self).deliver_now
	end


	#returns token using SecureRandom module generator and url_sage base 64 to make a value usable in urls
	def self.new_token
		SecureRandom.urlsafe_base64
	end

	#similar to create an activation hash 
	def create_reset_hash
		self.reset_token = User.new_token
		update_columns(reset_digest: User.digest(reset_token), reset_sent_at: Time.zone.now)
	end


	#Returns true if the reset password was created before 3 hours  has passed
	def reset_expired?
		reset_sent_at > 3.hours.ago
	end

	# returns hash digest froma string
 	
 	def self.digest(string)
 		BCrypt::Password.create(string)
 	end

	#verfies a string comparing it to a digest in the databse, returns t

	def authentic?(attribute, string)
		# uses send to call the attribute
		attr_digest = self.send("#{attribute}_digest")
		if attr_digest.nil?
			false
		else
			#creates a new instance of Bcrypt to use method is_password? in our attr_digest , returns false if the string token doesn't match the digest hash
			BCrypt::Password.new(attr_digest).is_password?(string)
		end
	end

	#update the columns of activation

	def activation 
		update_columns(activated: true, activated_at: Time.zone.now)
	end

	#creates a token as an instace variable u and saves the digest of that token in the atribute remember_token

	def remember
		self.remember_token = User.new_token
		update_attribute(:remember_token, User.digest(remember_token))
	end

	#deletes token

	def forget
		self.remember_token = nil 
		update_attribute(:remember_digest, nil)
	end

	#push an user as a request_friends, creating a relationship

	def friend_request(other_user)
		requested_friends.push(other_user)
	end

	#cancels a request made

	def cancel_request(other_user)
		if requested_friends.include?(other_user) && requested_relationships.find_by(friend_pasive_id: other_user.id).accepted == false

		end
	end

	#accepts a relationship created by other user

	def accept_request(other_user)
		received_relationships.find_by(friend_active_id: other_user.id).update_attribute(:accepted, true)
	end

	#checks if the user request was sent

	def request_sent?(other_user)
		if requested_friends.include?(other_user)
			return true
		else 
			return false
		end
	end

	#checks if the user recieve a friend request

	def request_receive?(other_user)
		if received_friends.include?(other_user)
			return true
		else 
			return false
		end
	end

	#checks if a relationship exist and if it was accepted
	def is_friend?(other_user)

		if requested_friends.include?(other_user) &&  requested_relationships.find_by(friend_pasive_id: other_user.id).accepted?
			return true
		elsif received_friends.include?(other_user) && received_relationships.find_by(friend_active_id: other_user.id).accepted?	
			return true
		else 
			return false
		end
	end

	#deletes a relationship only if you requested it or if you accepted it

	def delete_friend(other_user)		
		if requested_friends.include?(other_user) 
				requested_friends.delete(other_user)
		elsif received_friends.include?(other_user) && received_relationships.find_by(friend_active_id: other_user.id).accepted?
				received_friends.delete(other_user)
		end
	end

	def user_feed
		#sql query for the requested  and accepted friendships ID's using the user id
		active_ids = "SELECT friend_pasive_id FROM relationships WHERE friend_active_id = :user_id AND accepted = 1"
		#sql query for the received and accepted friendships ID's using the user id
		pasive_ids = "SELECT friend_active_id FROM relationships WHERE friend_pasive_id = :user_id AND accepted = 1"
		#sql for the post using both previous ids and the users id
		return Post.where("user_id IN (#{active_ids}) OR user_id IN (#{pasive_ids}) OR user_id = :user_id", user_id: self.id)
	end

	private

	def downcase_email
		self.email = self.email.downcase
	end

	#creates activation token  and its digest and assign them like instace variables
	def create_activation_hash
		self.activation_token = User.new_token
		self.activation_digest = User.digest(activation_token)
	end



end
