require "erb"

class OrdersCreateJob < ActiveJob::Base
  queue_as :default
  def perform(shop_domain:, webhook:)
    shop = Shop.find_by(shopify_domain: shop_domain)

    shop.with_shopify_session do
      logger.info("Starting Order Created Job")

      app = MailfunnelsUtil.get_app

      logger.info("Checking if subscriber exists")
      subscriber = Subscriber.where(app_id: app.id, email: "ayylmao@worldstarthiphop.com").first
      if subscriber.nil? == true
        logger.info("Subscriber does not exist, creating now!")
        subscriber = Subscriber.create(app_id: app.id, email: "ayylmao@worldstarthiphop.com")
      else
        logger.info("Subscriber exists!")
      end
      logger.info("Looking for trigger")
      trigger = Trigger.where(app_id: app.id, hook_id: '6').first
      if trigger.nil? == false
        logger.info("Trigger found!")
        trigger.put('', :num_triggered => trigger.num_triggered+1)
        logger.info("Looking for funnel")
        funnel = Funnel.where(app_id: app.id, trigger_id: trigger.id).first
        if funnel.nil? == false
          logger.info("Funnel found!")
          logger.info("Checking if subscriber is in email list")
          emailsub = EmailListSubscriber.where(app_id: app.id,
                                               email_list_id: funnel.email_list_id,
                                               subscriber_id: subscriber.id).first
          if emailsub.nil? == true
            logger.info("Subscriber not in list, adding now!")
            EmailListSubscriber.post('', {:app_id => app.id,
                                          :subscriber_id => subscriber.id,
                                          :email_list_id => funnel.email_list_id})
          else
            logger.info("Subscriber is already in list!")
          end
          logger.info("looking for link")
          link = Link.where(funnel_id: funnel.id, start_link: 1).first
          if link.nil? == false
            logger.info("Link found!")
            logger.info("looking for Node")
            node = Node.where(id: link.to_node_id).first
            if node.nil? == false
              logger.info("Node Found")

              logger.info "Checking if job already exists"
              job = EmailJob.where(app_id: app.id,
                                   funnel_id:funnel.id,
                                   node_id:node.id,
                                   subscriber_id:subscriber.id).first
              if job.nil? == true
                logger.info("Job does not exist creating now")
                logger.info("rendering email template for job")
                @template = EmailTemplate.find(node.email_template_id)
                html = File.open("app/views/email/template.html.erb").read
                @renderedhtml = "1"
                ERB.new(html, 0, "", "@renderedhtml").result(binding)
                EmailJob.post('', {:app_id => app.id,
                                   :funnel_id => funnel.id,
                                   :subscriber_id => subscriber.id,
                                   :executed => false,
                                   :node_id => node.id,
                                   :email_template_id => node.email_template_id,
                                   :sent => 0,
                                   :renderedEmail => @renderedhtml})
                logger.info("Sent Job to database!")
              else
                logger.info("Email job already exists with these parameters")
              end

              logger.info("Job Completed!")
            end
          end
        end
      end
    end
  end
end