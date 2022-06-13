json.extract! api_v1_article, :id, :user_id, :title, :body, :created_at, :updated_at
json.url api_v1_article_url(api_v1_article, format: :json)
