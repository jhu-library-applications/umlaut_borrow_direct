Rails.application.routes.draw do
  post "borrow_direct/:service_id/:request_id" => "borrow_direct#submit_request"
end
