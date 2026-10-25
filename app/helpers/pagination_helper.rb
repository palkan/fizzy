module PaginationHelper
  # @type instance: ActionView::Base
  #: (String | Symbol, GearedPagination::Page, ?data: Hash[Symbol, untyped], **untyped) ?{ () -> untyped } -> ActiveSupport::SafeBuffer
  def pagination_frame_tag(namespace, page, data: {}, **attributes, &)
    turbo_frame_tag pagination_frame_id_for(namespace, page.number), data: { timeline_target: "frame", **data }, role: "presentation", **attributes, &
  end

  #: (String | Symbol, GearedPagination::Page, ?activate_when_observed: bool, ?label: String, ?data: Hash[Symbol, untyped], **untyped) -> ActiveSupport::SafeBuffer?
  def link_to_next_page(namespace, page, activate_when_observed: false, label: default_pagination_label(activate_when_observed), data: {}, **attributes)
    if page.before_last? && !params[:previous]
      attributes[:class] = class_names(attributes[:class], "btn txt-small center-block center": !activate_when_observed)
      pagination_link(namespace, page.number + 1, label: label, activate_when_observed: activate_when_observed, data: data, **attributes)
    end
  end

  #: (String | Symbol, Integer, ?activate_when_observed: bool, ?label: String, ?url_params: Hash[Symbol, untyped], ?data: Hash[Symbol, untyped], **untyped) -> ActiveSupport::SafeBuffer
  def pagination_link(namespace, page_number, activate_when_observed: false, label: default_pagination_label(activate_when_observed), url_params: {}, data: {}, **attributes)
    link_to label, url_for(params.permit!.to_h.merge(page: page_number, **url_params)),
      "aria-label": "Load page #{page_number}",
      id: "#{namespace}-pagination-link-#{page_number}",
      class: class_names(attributes.delete(:class), "pagination-link", { "pagination-link--active-when-observed" => activate_when_observed }),
      data: {
        frame: pagination_frame_id_for(namespace, page_number),
        pagination_target: "paginationLink",
        action: ("click->pagination#loadPage:prevent" unless activate_when_observed),
        **data
      },
      **attributes
  end

  #: (String | Symbol, Integer) -> String
  def pagination_frame_id_for(namespace, page_number)
    "#{namespace}-pagination-contents-#{page_number}"
  end

  #: (String | Symbol, GearedPagination::Page, **untyped) { () -> untyped } -> ActiveSupport::SafeBuffer
  def with_manual_pagination(name, page, **properties)
    pagination_list name, **properties do
      concat(pagination_frame_tag(name, page) do
        yield
        concat link_to_next_page(name, page)
      end)
    end
  end

  #: (String | Symbol, GearedPagination::Page, **untyped) { () -> untyped } -> ActiveSupport::SafeBuffer
  def with_automatic_pagination(name, page, **properties)
    pagination_list name, paginate_on_scroll: true, **properties do
      concat(pagination_frame_tag(name, page) do
        yield
        concat link_to_next_page(name, page, activate_when_observed: true)
      end)
    end
  end

  #: (User::DayTimeline) ?{ () -> untyped } -> ActiveSupport::SafeBuffer
  def day_timeline_pagination_frame_tag(day_timeline, &)
    turbo_frame_tag day_timeline_pagination_frame_id_for(day_timeline.day), data: { timeline_target: "frame" }, role: "presentation", refresh: :morph, &
  end

  #: (ActiveSupport::TimeWithZone) -> String
  def day_timeline_pagination_frame_id_for(day)
    "day-timeline-pagination-contents-#{day.strftime("%Y-%m-%d")}"
  end

  #: (User::DayTimeline, Filter) -> ActiveSupport::SafeBuffer?
  def day_timeline_pagination_link(day_timeline, filter)
    if next_day = day_timeline.next_day
      link_to "Load more…", events_days_path(day: next_day.strftime("%Y-%m-%d"), **filter.as_params),
        class: "day-timeline-pagination-link", data: { frame: day_timeline_pagination_frame_id_for(next_day), pagination_target: "paginationLink" }
    end
  end

  private
    #: (String | Symbol, ?tag_element: Symbol, ?paginate_on_scroll: bool, **untyped) ?{ () -> untyped } -> ActiveSupport::SafeBuffer
    def pagination_list(name, tag_element: :div, paginate_on_scroll: false, **properties, &block)
      classes = properties.delete(:class)
      properties[:id] ||= "#{name}-pagination-list"
      tag.public_send tag_element,
        class: token_list(name, "display-contents", classes),
        data: { controller: "pagination", pagination_paginate_on_intersection_value: paginate_on_scroll },
        **properties,
        &block
    end

    #: (bool) -> String
    def default_pagination_label(activate_when_observed)
      "Load more…"
    end
end
