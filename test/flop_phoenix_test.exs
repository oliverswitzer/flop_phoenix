defmodule Flop.PhoenixTest do
  use ExUnit.Case
  use Phoenix.Component
  use Phoenix.HTML

  import Flop.Phoenix
  import Flop.Phoenix.Factory
  import Flop.Phoenix.TestHelpers
  import Phoenix.LiveViewTest

  alias Flop.Filter
  alias MyApp.Pet
  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.LiveStream
  alias Plug.Conn.Query

  doctest Flop.Phoenix, import: true

  @route_helper_opts [%{}, :pets]

  attr :caption, :string, default: nil
  attr :on_sort, JS, default: nil
  attr :event, :string, default: nil
  attr :id, :string, default: "some-table"
  attr :meta, Flop.Meta, default: %Flop.Meta{flop: %Flop{}}
  attr :opts, :list, default: []
  attr :target, :string, default: nil
  attr :hide_age, :boolean, default: false
  attr :show_age, :boolean, default: true
  attr :path, :any, default: {__MODULE__, :route_helper, @route_helper_opts}

  attr :items, :list,
    default: [
      %{name: "George", email: "george@george.pet", age: 8, species: "dog"}
    ]

  defp render_table(assigns) do
    parse_heex(~H"""
    <Flop.Phoenix.table
      caption={@caption}
      on_sort={@on_sort}
      event={@event}
      id={@id}
      items={@items}
      meta={@meta}
      opts={@opts}
      path={@path}
      target={@target}
    >
      <:col :let={pet} label="Name" field={:name}><%= pet.name %></:col>
      <:col :let={pet} label="Email" field={:email}><%= pet.email %></:col>
      <:col :let={pet} label="Age" hide={@hide_age} show={@show_age}>
        <%= pet.age %>
      </:col>
      <:col :let={pet} label="Species" field={:species}><%= pet.species %></:col>
      <:col>column without label</:col>
    </Flop.Phoenix.table>
    """)
  end

  def route_helper(%{}, action, query) do
    URI.to_string(%URI{path: "/#{action}", query: Query.encode(query)})
  end

  def path_func(params) do
    {page, params} = Keyword.pop(params, :page)
    query = Query.encode(params)
    if page, do: "/pets/page/#{page}?#{query}", else: "/pets?#{query}"
  end

  describe "pagination/1" do
    test "renders pagination wrapper" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} on_paginate={%JS{}} />
        """)

      wrapper = Floki.find(html, "nav")

      assert Floki.attribute(wrapper, "aria-label") == ["pagination"]
      assert Floki.attribute(wrapper, "class") == ["pagination"]
      assert Floki.attribute(wrapper, "role") == ["navigation"]
    end

    test "does not render anything if there is only one page" do
      assigns = %{meta: build(:meta_one_page)}

      assert parse_heex(~H"""
             <Flop.Phoenix.pagination meta={@meta} on_paginate={%JS{}} />
             """) == []
    end

    test "does not render anything if there are no results" do
      assigns = %{meta: build(:meta_no_results)}

      assert parse_heex(~H"""
             <Flop.Phoenix.pagination meta={@meta} on_paginate={%JS{}} />
             """) == []
    end

    test "does not render next and previous links if user specifies not to" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          on_paginate={%JS{}}
          opts={[render_next_and_previous_links: false]}
        />
        """)

      assert [] = Floki.find(html, ".pagination-next")
      assert [] = Floki.find(html, ".pagination-previous")
    end

    test "allows to overwrite wrapper class" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          on_paginate={%JS{}}
          opts={[wrapper_attrs: [class: "boo"]]}
        />
        """)

      assert [wrapper] = Floki.find(html, "nav")

      assert Floki.attribute(wrapper, "aria-label") == ["pagination"]
      assert Floki.attribute(wrapper, "class") == ["boo"]
      assert Floki.attribute(wrapper, "role") == ["navigation"]
    end

    test "allows to add attributes to wrapper" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          on_paginate={%JS{}}
          opts={[wrapper_attrs: [title: "paginate"]]}
        />
        """)

      assert [wrapper] = Floki.find(html, "nav")

      assert Floki.attribute(wrapper, "aria-label") == ["pagination"]
      assert Floki.attribute(wrapper, "class") == ["pagination"]
      assert Floki.attribute(wrapper, "role") == ["navigation"]
      assert Floki.attribute(wrapper, "title") == ["paginate"]
    end

    test "renders previous link" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")

      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]
    end

    test "uses phx-click with on_paginate without path" do
      assigns = %{
        meta: build(:meta_on_second_page),
        on_paginate: JS.push("paginate")
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} on_paginate={@on_paginate} />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")

      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "data-phx-link") == []
      assert Floki.attribute(link, "data-phx-link-state") == []
      assert Floki.attribute(link, "href") == ["#"]
      assert Floki.attribute(link, "phx-value-page") == ["1"]
      assert [phx_click] = Floki.attribute(link, "phx-click")
      assert Jason.decode!(phx_click) == [["push", %{"event" => "paginate"}]]
    end

    test "uses phx-click with on_paginate and path" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          on_paginate={JS.push("paginate")}
        />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")

      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]
      assert Floki.attribute(link, "phx-value-page") == ["1"]
      assert [phx_click] = Floki.attribute(link, "phx-click")
      assert Jason.decode!(phx_click) == [["push", %{"event" => "paginate"}]]
    end

    test "supports a function/args tuple as path" do
      assigns = %{
        meta: build(:meta_on_second_page),
        path: {&route_helper/3, @route_helper_opts}
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path={@path} />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]
    end

    test "supports a function as path" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path={&path_func/1} />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Next')")
      assert Floki.attribute(link, "href") == ["/pets/page/2?page_size=10"]
    end

    test "supports a URI string as path" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]
    end

    test "renders previous link when using click event handling" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")

      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "phx-click") == ["paginate"]
      assert Floki.attribute(link, "phx-value-page") == ["1"]
      assert Floki.attribute(link, "href") == ["#"]
    end

    test "adds phx-target to previous link" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" target="here" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "phx-target") == ["here"]
    end

    test "merges query parameters into existing parameters" do
      assigns = %{
        meta: build(:meta_on_second_page),
        path: {&route_helper/3, @route_helper_opts ++ [[category: "dinosaurs"]]}
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path={@path} />
        """)

      assert [previous] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(previous, "class") == ["pagination-previous"]
      assert Floki.attribute(previous, "data-phx-link") == ["patch"]
      assert Floki.attribute(previous, "data-phx-link-state") == ["push"]

      assert [href] = Floki.attribute(previous, "href")
      assert_urls_match(href, "/pets?category=dinosaurs&page_size=10")
    end

    test "merges query parameters into existing path query parameters" do
      assigns = %{
        meta: build(:meta_on_second_page),
        path: {&route_helper/3, @route_helper_opts ++ [[category: "dinosaurs"]]}
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets?category=dinosaurs" />
        """)

      assert [previous] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(previous, "class") == ["pagination-previous"]
      assert Floki.attribute(previous, "data-phx-link") == ["patch"]
      assert Floki.attribute(previous, "data-phx-link-state") == ["push"]

      assert [href] = Floki.attribute(previous, "href")
      assert_urls_match(href, "/pets?page_size=10&category=dinosaurs")
    end

    test "allows to overwrite previous link attributes and content" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[
            previous_link_attrs: [class: "prev", title: "p-p-previous"],
            previous_link_content: tag(:i, class: "fas fa-chevron-left")
          ]}
        />
        """)

      assert [link] = Floki.find(html, "a[title='p-p-previous']")
      assert Floki.attribute(link, "class") == ["prev"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]

      assert link |> Floki.children() |> Floki.raw_html() ==
               "<i class=\"fas fa-chevron-left\"></i>"
    end

    test "disables previous link if on first page" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [previous_link] = Floki.find(html, "span:fl-contains('Previous')")

      assert Floki.attribute(previous_link, "class") == [
               "pagination-previous disabled"
             ]
    end

    test "disables previous link if on first page when using click handlers" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" />
        """)

      assert [previous_link] = Floki.find(html, "span:fl-contains('Previous')")

      assert Floki.attribute(previous_link, "class") == [
               "pagination-previous disabled"
             ]
    end

    test "allows to overwrite previous link class and content if disabled" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[
            previous_link_attrs: [class: "prev", title: "no"],
            previous_link_content: "Prev"
          ]}
        />
        """)

      assert [previous_link] = Floki.find(html, "span:fl-contains('Prev')")

      assert Floki.attribute(previous_link, "class") == ["prev disabled"]
      assert Floki.attribute(previous_link, "title") == ["no"]
      assert String.trim(Floki.text(previous_link)) == "Prev"
    end

    test "renders next link" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Next')")

      assert Floki.attribute(link, "class") == ["pagination-next"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?page=3&page_size=10")
    end

    test "renders next link when using click event handling" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Next')")

      assert Floki.attribute(link, "class") == ["pagination-next"]
      assert Floki.attribute(link, "phx-click") == ["paginate"]
      assert Floki.attribute(link, "phx-value-page") == ["3"]
      assert Floki.attribute(link, "href") == ["#"]
    end

    test "adds phx-target to next link" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" target="here" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Next')")
      assert Floki.attribute(link, "phx-target") == ["here"]
    end

    test "allows to overwrite next link attributes and content" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[
            next_link_attrs: [class: "next", title: "n-n-next"],
            next_link_content: tag(:i, class: "fas fa-chevron-right")
          ]}
        />
        """)

      assert [link] = Floki.find(html, "a[title='n-n-next']")
      assert Floki.attribute(link, "class") == ["next"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?page=3&page_size=10")

      assert link |> Floki.children() |> Floki.raw_html() ==
               "<i class=\"fas fa-chevron-right\"></i>"
    end

    test "disables next link if on last page" do
      assigns = %{meta: build(:meta_on_last_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [next] = Floki.find(html, "span:fl-contains('Next')")
      assert Floki.attribute(next, "class") == ["pagination-next disabled"]
      assert Floki.attribute(next, "href") == []
    end

    test "renders next link on last page when using click event handling" do
      assigns = %{meta: build(:meta_on_last_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" />
        """)

      assert [next] = Floki.find(html, "span:fl-contains('Next')")
      assert Floki.attribute(next, "class") == ["pagination-next disabled"]
      assert Floki.attribute(next, "href") == []
    end

    test "allows to overwrite next link attributes and content when disabled" do
      assigns = %{meta: build(:meta_on_last_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[
            next_link_attrs: [class: "next", title: "no"],
            next_link_content: "N-n-next"
          ]}
        />
        """)

      assert [next_link] = Floki.find(html, "span:fl-contains('N-n-next')")
      assert Floki.attribute(next_link, "class") == ["next disabled"]
      assert Floki.attribute(next_link, "title") == ["no"]
    end

    test "renders page links" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [_] = Floki.find(html, "ul[class='pagination-links']")

      assert [link] = Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.attribute(link, "class") == ["pagination-link"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]
      assert String.trim(Floki.text(link)) == "1"

      assert [link] = Floki.find(html, "a[aria-label='Go to page 2']")
      assert Floki.attribute(link, "class") == ["pagination-link is-current"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?page=2&page_size=10")
      assert String.trim(Floki.text(link)) == "2"

      assert [link] = Floki.find(html, "a[aria-label='Go to page 3']")
      assert Floki.attribute(link, "class") == ["pagination-link"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?page=3&page_size=10")
      assert String.trim(Floki.text(link)) == "3"
    end

    test "renders page links when using click event handling" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" />
        """)

      assert [link] = Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.attribute(link, "href") == ["#"]
      assert Floki.attribute(link, "phx-click") == ["paginate"]
      assert Floki.attribute(link, "phx-value-page") == ["1"]
      assert Floki.text(link) =~ "1"
    end

    test "adds phx-target to page link" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" target="here" />
        """)

      assert [link] = Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.attribute(link, "phx-target") == ["here"]
    end

    test "doesn't render pagination links if set to hide" do
      assigns = %{meta: build(:meta_on_second_page), opts: [page_links: :hide]}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert Floki.find(html, ".pagination-links") == []
    end

    test "doesn't render pagination links if set to hide when passing event" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          event="paginate"
          opts={[page_links: :hide]}
        />
        """)

      assert Floki.find(html, ".pagination-links") == []
    end

    test "allows to overwrite pagination list attributes" do
      assigns = %{meta: build(:meta_on_first_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[pagination_list_attrs: [class: "p-list", title: "boop"]]}
        />
        """)

      assert [list] = Floki.find(html, "ul.p-list")
      assert Floki.attribute(list, "title") == ["boop"]
    end

    test "allows to overwrite pagination link attributes" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[pagination_link_attrs: [class: "p-link", beep: "boop"]]}
        />
        """)

      assert [link] = Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.attribute(link, "beep") == ["boop"]
      assert Floki.attribute(link, "class") == ["p-link"]

      # current link attributes are unchanged
      assert [link] = Floki.find(html, "a[aria-label='Go to page 2']")
      assert Floki.attribute(link, "beep") == []
      assert Floki.attribute(link, "class") == ["pagination-link is-current"]
    end

    test "allows to overwrite current attributes" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[current_link_attrs: [class: "link is-active", beep: "boop"]]}
        />
        """)

      assert [link] = Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.attribute(link, "class") == ["pagination-link"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]
      assert String.trim(Floki.text(link)) == "1"

      assert [link] = Floki.find(html, "a[aria-label='Go to page 2']")
      assert Floki.attribute(link, "beep") == ["boop"]
      assert Floki.attribute(link, "class") == ["link is-active"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?page=2&page_size=10")
      assert String.trim(Floki.text(link)) == "2"
    end

    test "allows to overwrite pagination link aria label" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination
          meta={@meta}
          path="/pets"
          opts={[pagination_link_aria_label: &"On to page #{&1}"]}
        />
        """)

      assert [link] = Floki.find(html, "a[aria-label='On to page 1']")
      assert Floki.attribute(link, "class") == ["pagination-link"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert Floki.attribute(link, "href") == ["/pets?page_size=10"]
      assert String.trim(Floki.text(link)) == "1"

      assert [link] = Floki.find(html, "a[aria-label='On to page 2']")
      assert Floki.attribute(link, "class") == ["pagination-link is-current"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?page=2&page_size=10")
      assert String.trim(Floki.text(link)) == "2"
    end

    test "adds order parameters to links" do
      assigns = %{
        meta:
          build(
            :meta_on_second_page,
            flop: %Flop{
              order_by: [:fur_length, :curiosity],
              order_directions: [:asc, :desc],
              page: 2,
              page_size: 10
            }
          )
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      default_query = [
        page_size: 10,
        order_directions: ["asc", "desc"],
        order_by: ["fur_length", "curiosity"]
      ]

      expected_query = fn
        1 -> default_query
        page -> Keyword.put(default_query, :page, page)
      end

      assert [previous] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(previous, "class") == ["pagination-previous"]
      assert Floki.attribute(previous, "data-phx-link") == ["patch"]
      assert Floki.attribute(previous, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(previous, "href")
      assert_urls_match(href, "/pets", expected_query.(1))

      assert [one] = Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.attribute(one, "class") == ["pagination-link"]
      assert Floki.attribute(one, "data-phx-link") == ["patch"]
      assert Floki.attribute(one, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(one, "href")
      assert_urls_match(href, "/pets", expected_query.(1))

      assert [next] = Floki.find(html, "a:fl-contains('Next')")
      assert Floki.attribute(next, "class") == ["pagination-next"]
      assert Floki.attribute(next, "data-phx-link") == ["patch"]
      assert Floki.attribute(next, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(next, "href")
      assert_urls_match(href, "/pets", expected_query.(3))
    end

    test "hides default order and limit" do
      assigns = %{
        meta:
          build(
            :meta_on_second_page,
            flop: %Flop{
              page_size: 20,
              order_by: [:name],
              order_directions: [:asc]
            },
            schema: Pet
          )
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [prev] = Floki.find(html, "a:fl-contains('Previous')")
      assert [href] = Floki.attribute(prev, "href")

      refute href =~ "page_size="
      refute href =~ "order_by[]="
      refute href =~ "order_directions[]="
    end

    test "does not require path when passing event" do
      assigns = %{meta: build(:meta_on_second_page)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} event="paginate" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "phx-click") == ["paginate"]
      assert Floki.attribute(link, "phx-value-page") == ["1"]
      assert Floki.attribute(link, "href") == ["#"]
    end

    test "raises if neither path nor event nor on_paginate are passed" do
      assigns = %{meta: build(:meta_on_second_page)}

      assert_raise Flop.Phoenix.PathOrJSError,
                   fn ->
                     rendered_to_string(~H"""
                     <Flop.Phoenix.pagination meta={@meta} />
                     """)
                   end
    end

    test "adds filter parameters to links" do
      assigns = %{
        meta:
          build(
            :meta_on_second_page,
            flop: %Flop{
              page: 2,
              page_size: 10,
              filters: [
                %Flop.Filter{field: :fur_length, op: :>=, value: 5},
                %Flop.Filter{
                  field: :curiosity,
                  op: :in,
                  value: [:a_lot, :somewhat]
                }
              ]
            }
          )
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      default_query = [
        page_size: 10,
        filters: %{
          "0" => %{
            field: "fur_length",
            op: ">=",
            value: "5"
          },
          "1" => %{
            field: "curiosity",
            op: "in",
            value: ["a_lot", "somewhat"]
          }
        }
      ]

      expected_query = fn
        1 -> default_query
        page -> Keyword.put(default_query, :page, page)
      end

      assert [previous] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(previous, "class") == ["pagination-previous"]
      assert Floki.attribute(previous, "data-phx-link") == ["patch"]
      assert Floki.attribute(previous, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(previous, "href")
      assert_urls_match(href, "/pets", expected_query.(1))

      assert [one] = Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.attribute(one, "class") == ["pagination-link"]
      assert Floki.attribute(one, "data-phx-link") == ["patch"]
      assert Floki.attribute(one, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(one, "href")
      assert_urls_match(href, "/pets", expected_query.(1))

      assert [next] = Floki.find(html, "a:fl-contains('Next')")
      assert Floki.attribute(next, "class") == ["pagination-next"]
      assert Floki.attribute(next, "data-phx-link") == ["patch"]
      assert Floki.attribute(next, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(next, "href")
      assert_urls_match(href, "/pets", expected_query.(3))
    end

    test "does not render ellipsis if total pages <= max pages" do
      # max pages smaller than total pages
      assigns = %{
        meta: build(:meta_on_second_page),
        opts: [page_links: {:ellipsis, 50}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert Floki.find(html, ".pagination-ellipsis") == []
      assert html |> Floki.find(".pagination-link") |> length() == 5

      # max pages equal to total pages
      assigns = %{
        meta: build(:meta_on_second_page),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert Floki.find(html, ".pagination-ellipsis") == []
      assert html |> Floki.find(".pagination-link") |> length() == 5
    end

    test "renders end ellipsis and last page link when on page 1" do
      assigns = %{
        meta: build(:meta_on_first_page, total_pages: 20),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 1
      assert html |> Floki.find(".pagination-link") |> length() == 6

      assert Floki.find(html, "a[aria-label='Go to page 20']")

      for i <- 1..5 do
        assert Floki.find(html, "a[aria-label='Go to page #{i}']")
      end
    end

    test "renders start ellipsis and first page link when on last page" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 20, total_pages: 20),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 1
      assert html |> Floki.find(".pagination-link") |> length() == 6

      assert Floki.find(html, "a[aria-label='Go to page 1']")

      for i <- 16..20 do
        assert Floki.find(html, "a[aria-label='Go to page #{i}']")
      end
    end

    test "renders ellipses when on even page with even number of max pages" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 12, total_pages: 20),
        opts: [page_links: {:ellipsis, 6}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 2
      assert html |> Floki.find(".pagination-link") |> length() == 8

      assert Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.find(html, "a[aria-label='Go to page 20']")

      for i <- 10..15 do
        assert Floki.find(html, ".a[aria-label='Go to page #{i}']")
      end
    end

    test "renders ellipses when on odd page with odd number of max pages" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 11, total_pages: 20),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 2
      assert html |> Floki.find(".pagination-link") |> length() == 7

      assert Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.find(html, "a[aria-label='Go to page 20']")

      for i <- 9..13 do
        assert Floki.find(html, "a[aria-label='Go to page #{i}']")
      end
    end

    test "renders ellipses when on even page with odd number of max pages" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 10, total_pages: 20),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 2
      assert html |> Floki.find(".pagination-link") |> length() == 7

      assert Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.find(html, "a[aria-label='Go to page 20']")

      for i <- 8..12 do
        assert Floki.find(html, "a[aria-label='Go to page #{i}']")
      end
    end

    test "renders ellipses when on odd page with even number of max pages" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 11, total_pages: 20),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 2
      assert html |> Floki.find(".pagination-link") |> length() == 7

      assert Floki.find(html, "a[aria-label='Go to page 1']")
      assert Floki.find(html, "a[aria-label='Go to page 20']")

      for i <- 9..13 do
        assert Floki.find(html, "a[aria-label='Go to page #{i}']")
      end
    end

    test "renders end ellipsis when on page close to the beginning" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 2, total_pages: 20),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 1
      assert html |> Floki.find(".pagination-link") |> length() == 6

      assert Floki.find(html, "a[aria-label='Go to page 20']")

      for i <- 1..5 do
        assert Floki.find(html, "a[aria-label='Go to page #{i}']")
      end
    end

    test "renders start ellipsis when on page close to the end" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 18, total_pages: 20),
        opts: [page_links: {:ellipsis, 5}]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert html |> Floki.find(".pagination-ellipsis") |> length() == 1
      assert html |> Floki.find(".pagination-link") |> length() == 6

      assert Floki.find(html, "a[aria-label='Go to page 1']")

      for i <- 16..20 do
        assert Floki.find(html, "a[aria-label='Go to page #{i}']")
      end
    end

    test "allows to overwrite ellipsis attributes and content" do
      assigns = %{
        meta: build(:meta_on_first_page, current_page: 10, total_pages: 20),
        opts: [
          page_links: {:ellipsis, 5},
          ellipsis_attrs: [class: "dotdotdot", title: "dot"],
          ellipsis_content: "dot dot dot"
        ]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert [el, _] = Floki.find(html, "span[class='dotdotdot']")
      assert el |> Floki.text() |> String.trim() == "dot dot dot"
    end

    test "always uses page/page_size" do
      assigns = %{
        meta:
          build(:meta_on_second_page,
            flop: %Flop{limit: 2, page: 2, page_size: nil, offset: 3}
          )
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.pagination meta={@meta} path="/pets" />
        """)

      assert [a | _] = Floki.find(html, "a")
      assert [href] = Floki.attribute(a, "href")
      assert href =~ "page_size=2"
      refute href =~ "limit=2"
      refute href =~ "offset=3"
    end

    @tag capture_log: true
    test "does not render anything if meta has errors" do
      {:error, meta} = Flop.validate(%{page: 0})
      assigns = %{meta: meta}

      assert parse_heex(~H"""
             <Flop.Phoenix.pagination meta={@meta} path="/pets" />
             """) == []
    end
  end

  describe "cursor_pagination/1" do
    test "renders pagination wrapper" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" />
        """)

      assert [wrapper] = Floki.find(html, "nav")
      assert Floki.attribute(wrapper, "aria-label") == ["pagination"]
      assert Floki.attribute(wrapper, "class") == ["pagination"]
      assert Floki.attribute(wrapper, "role") == ["navigation"]
    end

    test "allows to overwrite wrapper class" do
      assigns = %{
        meta: build(:meta_with_cursors),
        opts: [wrapper_attrs: [class: "boo"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert [wrapper] = Floki.find(html, "nav")
      assert Floki.attribute(wrapper, "aria-label") == ["pagination"]
      assert Floki.attribute(wrapper, "class") == ["boo"]
      assert Floki.attribute(wrapper, "role") == ["navigation"]
    end

    test "allows to add attributes to wrapper" do
      assigns = %{
        meta: build(:meta_with_cursors),
        opts: [wrapper_attrs: [title: "paginate"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert [wrapper] = Floki.find(html, "nav")
      assert Floki.attribute(wrapper, "aria-label") == ["pagination"]
      assert Floki.attribute(wrapper, "class") == ["pagination"]
      assert Floki.attribute(wrapper, "role") == ["navigation"]
      assert Floki.attribute(wrapper, "title") == ["paginate"]
    end

    test "renders previous link" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?last=10&before=B")
    end

    test "uses phx-click with on_paginate without path" do
      assigns = %{meta: build(:meta_with_cursors), js: JS.push("paginate")}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} on_paginate={@js} />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "data-phx-link") == []
      assert Floki.attribute(link, "data-phx-link-state") == []
      assert Floki.attribute(link, "href") == ["#"]
      assert Floki.attribute(link, "phx-value-to") == ["previous"]
      assert [phx_click] = Floki.attribute(link, "phx-click")
      assert Jason.decode!(phx_click) == [["push", %{"event" => "paginate"}]]
    end

    test "uses phx-click with on_paginate and path" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination
          meta={@meta}
          path="/pets"
          on_paginate={JS.push("paginate")}
        />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")

      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?before=B&last=10")

      assert Floki.attribute(link, "phx-value-to") == ["previous"]
      assert [phx_click] = Floki.attribute(link, "phx-click")
      assert [["push", %{"event" => "paginate"}]] = Jason.decode!(phx_click)
    end

    test "supports a function/args tuple as path" do
      assigns = %{
        meta: build(:meta_with_cursors),
        path: {&route_helper/3, @route_helper_opts}
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path={@path} />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?last=10&before=B")
    end

    test "supports a function as path" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path={&path_func/1} />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?last=10&before=B")
    end

    test "supports a URI string as path" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?before=B&last=10")
    end

    test "renders previous link when using click event handling" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} event="paginate" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "class") == ["pagination-previous"]
      assert Floki.attribute(link, "phx-click") == ["paginate"]
      assert Floki.attribute(link, "phx-value-to") == ["previous"]
      assert Floki.attribute(link, "href") == ["#"]
    end

    test "adds phx-target to previous link" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} event="paginate" target="here" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(link, "phx-target") == ["here"]
    end

    test "switches next and previous link" do
      assigns = %{meta: build(:meta_with_cursors)}

      # default
      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?last=10&before=B")
      assert [link] = Floki.find(html, "a:fl-contains('Next')")
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?first=10&after=C")

      # reverse
      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" reverse={true} />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Previous')")
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?first=10&after=C")

      assert [link] = Floki.find(html, "a:fl-contains('Next')")
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?last=10&before=B")
    end

    test "merges query parameters into existing parameters" do
      assigns = %{
        meta: build(:meta_with_cursors),
        path: {&route_helper/3, @route_helper_opts ++ [[category: "dinosaurs"]]}
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path={@path} />
        """)

      assert [previous] = Floki.find(html, "a:fl-contains('Previous')")
      assert Floki.attribute(previous, "class") == ["pagination-previous"]
      assert Floki.attribute(previous, "data-phx-link") == ["patch"]
      assert Floki.attribute(previous, "data-phx-link-state") == ["push"]

      assert [href] = Floki.attribute(previous, "href")
      assert_urls_match(href, "/pets?category=dinosaurs&last=10&before=B")
    end

    test "allows to overwrite previous link attributes and content" do
      assigns = %{
        meta: build(:meta_with_cursors),
        opts: [
          previous_link_attrs: [class: "prev", title: "p-p-previous"],
          previous_link_content: tag(:i, class: "fas fa-chevron-left")
        ]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" opts={@opts} />
        """)

      assert [link] = Floki.find(html, "a[title='p-p-previous']")
      assert Floki.attribute(link, "class") == ["prev"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?last=10&before=B")

      assert link |> Floki.children() |> Floki.raw_html() ==
               "<i class=\"fas fa-chevron-left\"></i>"
    end

    test "disables previous link if on first page" do
      assigns = %{meta: build(:meta_with_cursors, has_previous_page?: false)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" />
        """)

      assert [previous_link] = Floki.find(html, "span:fl-contains('Previous')")

      assert Floki.attribute(previous_link, "class") == [
               "pagination-previous disabled"
             ]
    end

    test "disables previous link if on first page when using click handlers" do
      assigns = %{meta: build(:meta_with_cursors, has_previous_page?: false)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} event="paginate" />
        """)

      assert [previous_link] = Floki.find(html, "span:fl-contains('Previous')")

      assert Floki.attribute(previous_link, "class") == [
               "pagination-previous disabled"
             ]
    end

    test "allows to overwrite previous link class and content if disabled" do
      assigns = %{meta: build(:meta_with_cursors, has_previous_page?: false)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination
          meta={@meta}
          event="paginate"
          opts={[
            previous_link_attrs: [class: "prev", title: "no"],
            previous_link_content: "Prev"
          ]}
        />
        """)

      assert [previous_link] = Floki.find(html, "span:fl-contains('Prev')")
      assert Floki.attribute(previous_link, "class") == ["prev disabled"]
      assert Floki.attribute(previous_link, "title") == ["no"]
      assert String.trim(Floki.text(previous_link)) == "Prev"
    end

    test "renders next link" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Next')")
      assert Floki.attribute(link, "class") == ["pagination-next"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?first=10&after=C")
    end

    test "renders next link when using click event handling" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} event="paginate" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Next')")
      assert Floki.attribute(link, "class") == ["pagination-next"]
      assert Floki.attribute(link, "phx-click") == ["paginate"]
      assert Floki.attribute(link, "phx-value-to") == ["next"]
      assert Floki.attribute(link, "href") == ["#"]
    end

    test "adds phx-target to next link" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} event="paginate" target="here" />
        """)

      assert [link] = Floki.find(html, "a:fl-contains('Next')")
      assert Floki.attribute(link, "phx-target") == ["here"]
    end

    test "allows to overwrite next link attributes and content" do
      assigns = %{meta: build(:meta_with_cursors)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination
          meta={@meta}
          path="/pets"
          opts={[
            next_link_attrs: [class: "next", title: "n-n-next"],
            next_link_content: tag(:i, class: "fas fa-chevron-right")
          ]}
        />
        """)

      assert [link] = Floki.find(html, "a[title='n-n-next']")
      assert Floki.attribute(link, "class") == ["next"]
      assert Floki.attribute(link, "data-phx-link") == ["patch"]
      assert Floki.attribute(link, "data-phx-link-state") == ["push"]
      assert [href] = Floki.attribute(link, "href")
      assert_urls_match(href, "/pets?first=10&after=C")

      assert link |> Floki.children() |> Floki.raw_html() ==
               "<i class=\"fas fa-chevron-right\"></i>"
    end

    test "disables next link if on last page" do
      assigns = %{meta: build(:meta_with_cursors, has_next_page?: false)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} path="/pets" />
        """)

      assert [next] = Floki.find(html, "span:fl-contains('Next')")
      assert Floki.attribute(next, "class") == ["pagination-next disabled"]
      assert Floki.attribute(next, "href") == []
    end

    test "renders next link on last page when using click event handling" do
      assigns = %{meta: build(:meta_with_cursors, has_next_page?: false)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination meta={@meta} event="paginate" />
        """)

      assert [next] = Floki.find(html, "span:fl-contains('Next')")
      assert Floki.attribute(next, "class") == ["pagination-next disabled"]
      assert Floki.attribute(next, "href") == []
    end

    test "allows to overwrite next link attributes and content when disabled" do
      assigns = %{meta: build(:meta_with_cursors, has_next_page?: false)}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.cursor_pagination
          meta={@meta}
          event="paginate"
          opts={[
            next_link_attrs: [class: "next", title: "no"],
            next_link_content: "N-n-next"
          ]}
        />
        """)

      assert [next_link] = Floki.find(html, "span:fl-contains('N-n-next')")
      assert Floki.attribute(next_link, "class") == ["next disabled"]
      assert Floki.attribute(next_link, "title") == ["no"]
    end

    test "raises if neither path nor event are passed" do
      assigns = %{meta: build(:meta_with_cursors)}

      assert_raise Flop.Phoenix.PathOrJSError,
                   fn ->
                     rendered_to_string(~H"""
                     <Flop.Phoenix.cursor_pagination meta={@meta} />
                     """)
                   end
    end

    @tag capture_log: true
    test "does not render anything if meta has errors" do
      {:error, meta} = Flop.validate(%{first: 1, last: 1})
      assigns = %{meta: meta}

      assert parse_heex(~H"""
             <Flop.Phoenix.cursor_pagination meta={@meta} path="/path" />
             """) == []
    end
  end

  describe "table/1" do
    test "allows to set table attributes" do
      # attribute from global config
      html = render_table(%{opts: []})
      assert [table] = Floki.find(html, "table")
      assert Floki.attribute(table, "class") == ["sortable-table"]

      html = render_table(%{opts: [table_attrs: [class: "funky-table"]]})
      assert [table] = Floki.find(html, "table")
      assert Floki.attribute(table, "class") == ["funky-table"]
    end

    test "optionally adds a table container" do
      html = render_table(%{opts: []})
      assert Floki.find(html, ".table-container") == []

      html = render_table(%{opts: [container: true]})
      assert [_] = Floki.find(html, ".table-container")
    end

    test "allows to set container attributes" do
      html =
        render_table(%{
          opts: [
            container_attrs: [class: "container", data_some: "thing"],
            container: true
          ]
        })

      assert [container] = Floki.find(html, "div.container")
      assert Floki.attribute(container, "data_some") == ["thing"]
    end

    test "allows to set tbody attributes" do
      html =
        render_table(%{
          opts: [
            tbody_attrs: [class: "mango_body"],
            container: true
          ]
        })

      assert [_] = Floki.find(html, "tbody.mango_body")
    end

    test "setting thead attributes" do
      html =
        render_table(%{
          opts: [
            thead_attrs: [class: "text-left text-zinc-500 leading-6"],
            container: true
          ]
        })

      assert [_] = Floki.find(html, "thead.text-left.text-zinc-500.leading-6")
    end

    test "allows to set id on table, tbody and container" do
      html = render_table(%{id: "some-id", opts: [container: true]})
      assert [_] = Floki.find(html, "div#some-id-container")
      assert [_] = Floki.find(html, "table#some-id")
      assert [_] = Floki.find(html, "tbody#some-id-tbody")
    end

    test "sets default ID based on schema module" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        event: "sort-table",
        items: ["George"]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} event="sort">
          <:col></:col>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "table#pet-table")
      assert [_] = Floki.find(html, "tbody#pet-table-tbody")
    end

    test "sets default ID without schema module" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          items={["George"]}
          meta={%Flop.Meta{flop: %Flop{}}}
          opts={[container: true]}
          event="sort"
        >
          <:col></:col>
        </Flop.Phoenix.table>
        """)

      assert [_] =
               Floki.find(html, "div.table-container#sortable-table-container")

      assert [_] = Floki.find(html, "table#sortable-table")
      assert [_] = Floki.find(html, "tbody#sortable-table-tbody")
    end

    test "does not set row ID if items are not a stream" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        event: "sort-table",
        items: ["George"]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} event="sort">
          <:col></:col>
        </Flop.Phoenix.table>
        """)

      assert [tr] = Floki.find(html, "tbody tr")
      assert Floki.attribute(tr, "id") == []
    end

    test "allows to set row ID function" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        event: "sort-table",
        items: [%Pet{id: 1, name: "George"}, %Pet{id: 2, name: "Mary"}],
        row_id: &"pets-#{&1.name}"
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} row_id={@row_id} event="sort">
          <:col></:col>
        </Flop.Phoenix.table>
        """)

      assert [tr_1, tr_2] = Floki.find(html, "tbody tr")
      assert Floki.attribute(tr_1, "id") == ["pets-George"]
      assert Floki.attribute(tr_2, "id") == ["pets-Mary"]
    end

    test "uses default row ID function if items are a stream" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        stream: LiveStream.new(:pets, 0, [%Pet{id: 1}, %Pet{id: 2}], [])
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@stream} meta={@meta} event="sort">
          <:col></:col>
        </Flop.Phoenix.table>
        """)

      assert [tr_1, tr_2] = Floki.find(html, "tbody tr")
      assert Floki.attribute(tr_1, "id") == ["pets-1"]
      assert Floki.attribute(tr_2, "id") == ["pets-2"]
    end

    test "allows to override default row item function" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%Pet{name: "George"}],
        row_item: fn item -> Map.update!(item, :name, &String.upcase/1) end
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          items={@items}
          meta={@meta}
          row_item={@row_item}
          event="sort"
        >
          <:col :let={p}><%= p.name %></:col>
        </Flop.Phoenix.table>
        """)

      assert [td] = Floki.find(html, "tbody td")
      assert Floki.text(td) =~ "GEORGE"
    end

    test "allows to set tr and td classes via keyword lists" do
      html =
        render_table(%{
          opts: [
            thead_tr_attrs: [class: "mungo"],
            thead_th_attrs: [class: "bean"],
            tbody_tr_attrs: [class: "salt"],
            tbody_td_attrs: [class: "tolerance"]
          ]
        })

      assert [_] = Floki.find(html, "tr.mungo")
      assert [_, _, _, _, _] = Floki.find(html, "th.bean")
      assert [_] = Floki.find(html, "tr.salt")
      assert [_, _, _, _, _] = Floki.find(html, "td.tolerance")
    end

    test "evaluates attrs function for tr" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          path="/pets"
          items={[
            %{name: "Bruce Wayne", age: 42, occupation: "Superhero"},
            %{name: "April O'Neil", age: 39, occupation: "Crime Reporter"}
          ]}
          opts={[
            tbody_tr_attrs: fn item ->
              class =
                item.occupation
                |> String.downcase()
                |> String.replace(" ", "-")

              [class: class]
            end
          ]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col></:col>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "tr.superhero")
      assert [_] = Floki.find(html, "tr.crime-reporter")
    end

    test "evaluates tbody_td_attrs function for col slot / td" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          path="/pets"
          items={[
            %{name: "Mary Cratsworth-Shane", age: 99},
            %{name: "Bart Harley-Jarvis", age: 1}
          ]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col tbody_td_attrs={
            fn item ->
              [class: if(item.age > 17, do: "adult", else: "child")]
            end
          }>
          </:col>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "td.adult")
      assert [_] = Floki.find(html, "td.child")
    end

    test "evaluates tbody_td_attrs function in action columns" do
      assigns = %{
        attrs_fun: fn item ->
          [class: if(item.age > 17, do: "adult", else: "child")]
        end
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          items={[
            %{name: "Mary Cratsworth-Shane", age: 99},
            %{name: "Bart Harley-Jarvis", age: 1}
          ]}
          meta={%Flop.Meta{flop: %Flop{}}}
          on_sort={%JS{}}
        >
          <:col :let={u} label="Name"><%= u.name %></:col>
          <:action label="Buttons" tbody_td_attrs={@attrs_fun}>some action</:action>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "td.adult")
      assert [_] = Floki.find(html, "td.child")
    end

    test "allows to set td class on action" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          path="/pets"
          items={[%{}]}
          meta={%Flop.Meta{flop: %Flop{}}}
          opts={[tbody_td_attrs: [class: "tolerance"]]}
        >
          <:col></:col>
          <:action>action</:action>
        </Flop.Phoenix.table>
        """)

      assert [_, _] = Floki.find(html, "td.tolerance")
    end

    test "adds additional attributes to th" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          path="/pets"
          items={[%{name: "George", age: 8}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet} thead_th_attrs={[class: "name-header"]}>
            <%= pet.name %>
          </:col>
          <:col :let={pet} thead_th_attrs={[class: "age-header"]}>
            <%= pet.age %>
          </:col>
          <:action :let={pet} thead_th_attrs={[class: "action-header"]}>
            <.link navigate={"/show/pet/#{pet.name}"}>Show Pet</.link>
          </:action>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "th.name-header")
      assert [_] = Floki.find(html, "th.age-header")
      assert [_] = Floki.find(html, "th.action-header")
    end

    test "adds additional attributes to td" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          path="/pets"
          items={[%{name: "George", age: 8}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet} tbody_td_attrs={[class: "name-column"]}>
            <%= pet.name %>
          </:col>
          <:col :let={pet} tbody_td_attrs={[class: "age-column"]}>
            <%= pet.age %>
          </:col>
          <:action :let={pet} tbody_td_attrs={[class: "action-column"]}>
            <.link navigate={"/show/pet/#{pet.name}"}>Show Pet</.link>
          </:action>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "td.name-column")
      assert [_] = Floki.find(html, "td.age-column")
      assert [_] = Floki.find(html, "td.action-column")
    end

    test "overrides table_th_attrs with thead_th_attrs in col" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%{name: "George", age: 8}],
        opts: [thead_th_attrs: [class: "default-th-class"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} on_sort={%JS{}} opts={@opts}>
          <:col :let={i} thead_th_attrs={[class: "name-th-class"]}><%= i.name %></:col>
          <:col :let={i}><%= i.age %></:col>
        </Flop.Phoenix.table>
        """)

      assert [{"th", [{"class", "name-th-class"}], _}] =
               Floki.find(html, "th:first-child")

      assert [{"th", [{"class", "default-th-class"}], _}] =
               Floki.find(html, "th:last-child")
    end

    test "evaluates table th_wrapper_attrs" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%{name: "George", age: 8}],
        opts: [th_wrapper_attrs: [class: "default-th-wrapper-class"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} on_sort={%JS{}} opts={@opts}>
          <:col :let={i} field={:name}><%= i.name %></:col>
          <:col :let={i}><%= i.age %></:col>
        </Flop.Phoenix.table>
        """)

      assert [
               {"th", [],
                [{"span", [{"class", "default-th-wrapper-class"}], _}]}
             ] = Floki.find(html, "th:first-child")
    end

    test "overrides th_wrapper_attrs" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%{name: "George", age: 8}],
        opts: [th_wrapper_attrs: [class: "default-th-wrapper-class"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} on_sort={%JS{}} opts={@opts}>
          <:col
            :let={i}
            field={:name}
            th_wrapper_attrs={[class: "name-th-wrapper-class"]}
          >
            <%= i.name %>
          </:col>
          <:col :let={i} field={:age}><%= i.age %></:col>
        </Flop.Phoenix.table>
        """)

      assert [{"th", [], [{"span", [{"class", "name-th-wrapper-class"}], _}]}] =
               Floki.find(html, "th:first-child")

      assert [
               {"th", [],
                [{"span", [{"class", "default-th-wrapper-class"}], _}]}
             ] = Floki.find(html, "th:last-child")
    end

    test "overrides table_td_attrs with tbody_td_attrs in col" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%{name: "George", age: 8}],
        opts: [tbody_td_attrs: [class: "default-td-class"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} on_sort={%JS{}} opts={@opts}>
          <:col :let={i} tbody_td_attrs={[class: "name-td-class"]}><%= i.name %></:col>
          <:col :let={i}><%= i.age %></:col>
        </Flop.Phoenix.table>
        """)

      assert [{"td", [{"class", "name-td-class"}], _}] =
               Floki.find(html, "td:first-child")

      assert [{"td", [{"class", "default-td-class"}], _}] =
               Floki.find(html, "td:last-child")
    end

    test "overrides table_th_attrs with thead_th_attrs in action columns" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%{name: "George", age: 8}],
        opts: [thead_th_attrs: [class: "default-th-class"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} on_sort={%JS{}} opts={@opts}>
          <:col :let={i}><%= i.name %></:col>
          <:action thead_th_attrs={[class: "action-1-th-class"]}>action 1</:action>
          <:action>action 2</:action>
        </Flop.Phoenix.table>
        """)

      assert [{"th", [{"class", "action-1-th-class"}], _}] =
               Floki.find(html, "th:nth-child(2)")

      assert [{"th", [{"class", "default-th-class"}], _}] =
               Floki.find(html, "th:last-child")
    end

    test "overrides table_td_attrs with tbody_td_attrs in action columns" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%{name: "George", age: 8}],
        opts: [tbody_td_attrs: [class: "default-td-class"]]
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} on_sort={%JS{}} opts={@opts}>
          <:col :let={i}><%= i.name %></:col>
          <:action tbody_td_attrs={[class: "action-1-td-class"]}>action 1</:action>
          <:action>action 2</:action>
        </Flop.Phoenix.table>
        """)

      assert [{"td", [{"class", "action-1-td-class"}], _}] =
               Floki.find(html, "td:nth-child(2)")

      assert [{"td", [{"class", "default-td-class"}], _}] =
               Floki.find(html, "td:last-child")
    end

    test "doesn't render table if items list is empty" do
      assert [{"p", [], ["No results."]}] = render_table(%{items: []})
    end

    test "displays headers for action col" do
      assigns = %{meta: %Flop.Meta{flop: %Flop{}}}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table path="/pets" items={[%{}]} meta={@meta}>
          <:col></:col>
          <:action label="Buttons"></:action>
        </Flop.Phoenix.table>
        """)

      assert [th] = Floki.find(html, "th:fl-contains('Buttons')")
      assert Floki.children(th, include_text: false) == []
    end

    test "displays headers without sorting function" do
      html = render_table(%{})
      assert [th] = Floki.find(html, "th:fl-contains('Age')")
      assert Floki.children(th, include_text: false) == []
    end

    test "conditionally hides a column" do
      html = render_table(%{})
      assert [_] = Floki.find(html, "th:fl-contains('Age')")
      assert [_] = Floki.find(html, "td:fl-contains('8')")

      html = render_table(%{hide_age: false, show_age: true})
      assert [_] = Floki.find(html, "th:fl-contains('Age')")
      assert [_] = Floki.find(html, "td:fl-contains('8')")

      html = render_table(%{hide_age: true, show_age: true})
      assert [] = Floki.find(html, "th:fl-contains('Age')")
      assert [] = Floki.find(html, "td:fl-contains('8')")

      html = render_table(%{hide_age: false, show_age: false})
      assert [] = Floki.find(html, "th:fl-contains('Age')")
      assert [] = Floki.find(html, "td:fl-contains('8')")

      html = render_table(%{hide_age: true, show_age: false})
      assert [] = Floki.find(html, "th:fl-contains('Age')")
      assert [] = Floki.find(html, "td:fl-contains('8')")
    end

    test "conditionally hides an action column" do
      assigns = %{meta: %Flop.Meta{flop: %Flop{}}}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table path="/pets" items={[%{}]} meta={@meta}>
          <:col></:col>
          <:action label="Buttons"><a href="#">Show Pet</a></:action>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "th:fl-contains('Buttons')")

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table path="/pets" items={[%{}]} meta={@meta}>
          <:col></:col>
          <:action label="Buttons" show={true} hide={false}></:action>
        </Flop.Phoenix.table>
        """)

      assert [_] = Floki.find(html, "th:fl-contains('Buttons')")

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table path="/pets" items={[%{}]} meta={@meta}>
          <:col></:col>
          <:action label="Buttons" show={true} hide={true}></:action>
        </Flop.Phoenix.table>
        """)

      assert [] = Floki.find(html, "th:fl-contains('Buttons')")

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table path="/pets" items={[%{}]} meta={@meta}>
          <:col></:col>
          <:action label="Buttons" show={false} hide={true}></:action>
        </Flop.Phoenix.table>
        """)

      assert [] = Floki.find(html, "th:fl-contains('Buttons')")

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table path="/pets" items={[%{}]} meta={@meta}>
          <:col></:col>
          <:action label="Buttons" show={false} hide={false}></:action>
        </Flop.Phoenix.table>
        """)

      assert [] = Floki.find(html, "th:fl-contains('Buttons')")
    end

    test "displays headers with sorting function" do
      html = render_table(%{})

      assert [a] = Floki.find(html, "th a:fl-contains('Name')")
      assert Floki.attribute(a, "data-phx-link") == ["patch"]
      assert Floki.attribute(a, "data-phx-link-state") == ["push"]

      assert [href] = Floki.attribute(a, "href")
      assert_urls_match(href, "/pets?order_directions[]=asc&order_by[]=name")
    end

    test "uses phx-click with on_sort without path" do
      html =
        render_table(%{
          path: nil,
          on_sort: JS.push("sort")
        })

      assert [a] = Floki.find(html, "th a:fl-contains('Name')")
      assert Floki.attribute(a, "data-phx-link") == []
      assert Floki.attribute(a, "data-phx-link-state") == []
      assert Floki.attribute(a, "href") == ["#"]
      assert Floki.attribute(a, "phx-value-order") == ["name"]
      assert [phx_click] = Floki.attribute(a, "phx-click")
      assert Jason.decode!(phx_click) == [["push", %{"event" => "sort"}]]
    end

    test "application of custom sort directions per column" do
      assigns = %{
        meta: %Flop.Meta{
          flop: %Flop{
            order_by: [:ttfb],
            order_directions: [:desc_nulls_last]
          }
        },
        items: [
          %{
            ttfb: 2
          },
          %{
            ttfb: 1
          },
          %{
            ttfb: nil
          }
        ],
        ttfb_directions: {:asc_nulls_last, :desc_nulls_last}
      }

      html =
        ~H"""
        <Flop.Phoenix.table
          id="metrics-table"
          items={@items}
          meta={@meta}
          path="/navigations"
        >
          <:col
            :let={navigation}
            label="TTFB"
            field={:ttfb}
            directions={@ttfb_directions}
          >
            <%= navigation.ttfb %>
          </:col>
        </Flop.Phoenix.table>
        """
        |> rendered_to_string()
        |> Floki.parse_fragment!()

      [ttfb_sort_href] =
        html
        |> Floki.find("thead th a:fl-contains('TTFB')")
        |> Floki.attribute("href")

      %URI{query: query} = URI.parse(ttfb_sort_href)
      decoded_query = Query.decode(query)

      # assert href representing opposite direction of initial table sort
      assert %{
               "order_by" => ["ttfb"],
               "order_directions" => ["asc_nulls_last"]
             } = decoded_query
    end

    test "supports a function/args tuple as path" do
      html = render_table(%{path: {&route_helper/3, @route_helper_opts}})
      assert [a] = Floki.find(html, "th a:fl-contains('Name')")
      assert [href] = Floki.attribute(a, "href")
      assert_urls_match(href, "/pets?order_directions[]=asc&order_by[]=name")
    end

    test "supports a function as path" do
      html = render_table(%{path: &path_func/1})
      assert [a] = Floki.find(html, "th a:fl-contains('Name')")

      assert [href] = Floki.attribute(a, "href")
      assert_urls_match(href, "/pets?order_directions[]=asc&order_by[]=name")
    end

    test "supports a URI string as path" do
      html = render_table(%{path: "/pets"})
      assert [a] = Floki.find(html, "th a:fl-contains('Name')")

      [href] = Floki.attribute(a, "href")
      uri = URI.parse(href)
      assert uri.path == "/pets"

      assert URI.decode_query(uri.query) == %{
               "order_by[]" => "name",
               "order_directions[]" => "asc"
             }
    end

    test "displays headers with safe HTML values in action col" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          event="sort"
          id="user-table"
          items={[%{name: "George"}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet}>
            <%= pet.name %>
          </:col>
          <:action :let={pet} label={{:safe, "<span>Hello</span>"}}>
            <%= pet.name %>
          </:action>
        </Flop.Phoenix.table>
        """)

      assert [span] = Floki.find(html, "th span")
      assert Floki.text(span) == "Hello"
    end

    test "displays headers with safe HTML values" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          id="user-table"
          event="sort"
          items={[%{name: "George"}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet} label={{:safe, "<span>Hello</span>"}} field={:name}>
            <%= pet.name %>
          </:col>
        </Flop.Phoenix.table>
        """)

      assert [span] = Floki.find(html, "th a span")
      assert Floki.text(span) == "Hello"
    end

    test "adds aria-sort attribute to first ordered field" do
      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{
              order_by: [:email, :name],
              order_directions: [:asc, :desc]
            }
          }
        })

      assert [th_name, th_email, th_age, th_species, _] = Floki.find(html, "th")
      assert Floki.attribute(th_name, "aria-sort") == []
      assert Floki.attribute(th_email, "aria-sort") == ["ascending"]
      assert Floki.attribute(th_age, "aria-sort") == []
      assert Floki.attribute(th_species, "aria-sort") == []

      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{
              order_by: [:name, :email],
              order_directions: [:desc, :asc]
            }
          }
        })

      assert [th_name, th_email, th_age, th_species, _] = Floki.find(html, "th")
      assert Floki.attribute(th_name, "aria-sort") == ["descending"]
      assert Floki.attribute(th_email, "aria-sort") == []
      assert Floki.attribute(th_age, "aria-sort") == []
      assert Floki.attribute(th_species, "aria-sort") == []

      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [], order_directions: []}
          }
        })

      assert [th_name, th_email, th_age, th_species, _] = Floki.find(html, "th")
      assert Floki.attribute(th_name, "aria-sort") == []
      assert Floki.attribute(th_email, "aria-sort") == []
      assert Floki.attribute(th_age, "aria-sort") == []
      assert Floki.attribute(th_species, "aria-sort") == []
    end

    test "renders links with click handler" do
      html = render_table(%{event: "sort", path: nil})

      assert [a] = Floki.find(html, "th a:fl-contains('Name')")
      assert Floki.attribute(a, "href") == ["#"]
      assert Floki.attribute(a, "phx-click") == ["sort"]
      assert Floki.attribute(a, "phx-value-order") == ["name"]

      assert [a] = Floki.find(html, "th a:fl-contains('Email')")
      assert Floki.attribute(a, "href") == ["#"]
      assert Floki.attribute(a, "phx-click") == ["sort"]
      assert Floki.attribute(a, "phx-value-order") == ["email"]
    end

    test "adds phx-target to header links" do
      html = render_table(%{event: "sort", path: nil, target: "here"})

      assert [a] = Floki.find(html, "th a:fl-contains('Name')")
      assert Floki.attribute(a, "href") == ["#"]
      assert Floki.attribute(a, "phx-click") == ["sort"]
      assert Floki.attribute(a, "phx-target") == ["here"]
      assert Floki.attribute(a, "phx-value-order") == ["name"]
    end

    test "checks for sortability if for option is set" do
      # without :for option
      html = render_table(%{})

      assert [_] = Floki.find(html, "a:fl-contains('Name')")
      assert [_] = Floki.find(html, "a:fl-contains('Species')")

      # with :for assign
      html = render_table(%{meta: %Flop.Meta{flop: %Flop{}, schema: Pet}})

      assert [_] = Floki.find(html, "a:fl-contains('Name')")
      assert [] = Floki.find(html, "a:fl-contains('Species')")
    end

    test "hides default order and limit" do
      html =
        render_table(%{
          meta:
            build(
              :meta_on_second_page,
              flop: %Flop{
                page_size: 20,
                order_by: [:name],
                order_directions: [:desc]
              },
              schema: Pet
            )
        })

      assert [link] = Floki.find(html, "a:fl-contains('Name')")
      assert [href] = Floki.attribute(link, "href")

      refute href =~ "page_size="
      refute href =~ "order_by[]="
      refute href =~ "order_directions[]="
    end

    test "renders order direction symbol" do
      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [:name], order_directions: [:asc]}
          }
        })

      assert Floki.find(
               html,
               "a:fl-contains('Email') + span.order-direction"
             ) == []

      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [:email], order_directions: [:asc]}
          }
        })

      assert [span] =
               Floki.find(
                 html,
                 "th a:fl-contains('Email') + span.order-direction"
               )

      assert span |> Floki.text() |> String.trim() == "▴"

      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [:email], order_directions: [:desc]}
          }
        })

      assert [span] =
               Floki.find(
                 html,
                 "th a:fl-contains('Email') + span.order-direction"
               )

      assert span |> Floki.text() |> String.trim() == "▾"
    end

    test "only renders order direction symbol for first order field" do
      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{
              order_by: [:name, :email],
              order_directions: [:asc, :asc]
            }
          }
        })

      assert [span] =
               Floki.find(
                 html,
                 "th a:fl-contains('Name') + span.order-direction"
               )

      assert span |> Floki.text() |> String.trim() == "▴"

      assert Floki.find(
               html,
               "a:fl-contains('Email') + span.order-direction"
             ) == []
    end

    test "allows to set symbol class" do
      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [:name], order_directions: [:asc]}
          },
          opts: [symbol_attrs: [class: "other-class"]]
        })

      assert [_] = Floki.find(html, "span.other-class")
    end

    test "allows to override default symbols" do
      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [:name], order_directions: [:asc]}
          },
          opts: [symbol_asc: "asc"]
        })

      assert [span] = Floki.find(html, "span.order-direction")
      assert span |> Floki.text() |> String.trim() == "asc"

      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [:name], order_directions: [:desc]}
          },
          opts: [symbol_desc: "desc"]
        })

      assert [span] = Floki.find(html, "span.order-direction")
      assert span |> Floki.text() |> String.trim() == "desc"
    end

    test "allows to set indicator for unsorted column" do
      html =
        render_table(%{
          meta: %Flop.Meta{
            flop: %Flop{order_by: [:name], order_directions: [:asc]}
          },
          opts: [symbol_unsorted: "random"]
        })

      assert [span] =
               Floki.find(
                 html,
                 "th a:fl-contains('Email') + span.order-direction"
               )

      assert span |> Floki.text() |> String.trim() == "random"
    end

    test "renders notice if item list is empty" do
      assert [{"p", [], ["No results."]}] = render_table(%{items: []})
    end

    test "allows to set no_results_content" do
      assert render_table(%{
               items: [],
               opts: [no_results_content: content_tag(:div, do: "Nothing!")]
             }) == [{"div", [], ["Nothing!"]}]
    end

    test "renders row_click" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          event="sort"
          id="user-table"
          items={[%{name: "George", id: 1}]}
          meta={%Flop.Meta{flop: %Flop{}}}
          row_click={&JS.navigate("/show/#{&1.id}")}
        >
          <:col :let={pet} label="Name" field={:name}><%= pet.name %></:col>
          <:action :let={pet}>
            <.link navigate={"/show/pet/#{pet.name}"}>Show Pet</.link>
          </:action>
        </Flop.Phoenix.table>
        """)

      assert [{"table", _, [{"thead", _, _}, {"tbody", _, rows}]}] = html

      # two columns in total, second one is for action
      assert [_, _] = Floki.find(rows, "td")

      # only one column should have phx-click attribute
      assert [_] = Floki.find(rows, "td[phx-click]")
    end

    test "does not render row_click if not set" do
      html = render_table(%{})

      assert [
               {"table", [{"id", "some-table"}, {"class", "sortable-table"}],
                [
                  {"thead", _, _},
                  {"tbody", _, rows}
                ]}
             ] = html

      assert [] = Floki.find(rows, "td[phx-click]")
    end

    test "renders table action" do
      assigns = %{meta: %Flop.Meta{flop: %Flop{}}}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          path="/pets"
          items={[%{name: "George", age: 8}, %{name: "Mary", age: 10}]}
          meta={@meta}
        >
          <:col></:col>
          <:action :let={pet} label="Buttons">
            <.link navigate={"/show/pet/#{pet.name}"}>Show Pet</.link>
          </:action>
        </Flop.Phoenix.table>
        """)

      assert [
               {"table", _,
                [
                  {"thead", _, _},
                  {"tbody", _, rows}
                ]}
             ] = html

      assert [_] = Floki.find(rows, "a[href='/show/pet/Mary']")
      assert [_] = Floki.find(rows, "a[href='/show/pet/George']")
    end

    test "does not render action column if option is not set" do
      html = render_table(%{})

      assert [
               {"table", [{"id", "some-table"}, {"class", "sortable-table"}],
                [{"thead", _, _}, {"tbody", _, rows}]}
             ] = html

      assert [] = Floki.find(rows, "a")

      # test table has five column
      assert [_, _, _, _, _] = Floki.find(rows, "td")
    end

    test "renders table foot" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          event="sort"
          id="user-table"
          items={[%{name: "George"}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet} label="Name" field={:name}><%= pet.name %></:col>
          <:foot>
            <tr>
              <td>snap</td>
            </tr>
          </:foot>
        </Flop.Phoenix.table>
        """)

      assert [
               {"table", _,
                [
                  {"thead", _, _},
                  {"tbody", _, _},
                  {"tfoot", [], [{"tr", [], [{"td", [], ["snap"]}]}]}
                ]}
             ] = html
    end

    test "renders colgroup" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          event="sort"
          id="user-table"
          items={[%{name: "George", age: 8}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet} label="Name" field={:name} col_style="width: 60%;">
            <%= pet.name %>
          </:col>
          <:col :let={pet} label="Age" field={:age} col_style="width: 40%;">
            <%= pet.age %>
          </:col>
        </Flop.Phoenix.table>
        """)

      assert [
               {"table", _,
                [
                  {"colgroup", _,
                   [
                     {"col", [{"style", "width: 60%;"}], _},
                     {"col", [{"style", "width: 40%;"}], _}
                   ]},
                  {"thead", _, _},
                  {"tbody", _, _}
                ]}
             ] = html
    end

    test "does not render a colgroup if no style attribute is set" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          path="/pets"
          items={[%{name: "George", age: 8}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet} label="Name" field={:name}><%= pet.name %></:col>
          <:col :let={pet} label="Age" field={:age}><%= pet.age %></:col>
        </Flop.Phoenix.table>
        """)

      assert [
               {"table", _,
                [
                  {"thead", _, _},
                  {"tbody", _, _}
                ]}
             ] = html
    end

    test "renders colgroup on action col" do
      assigns = %{}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table
          event="sort"
          id="user-table"
          items={[%{name: "George", id: 1}]}
          meta={%Flop.Meta{flop: %Flop{}}}
        >
          <:col :let={pet} label="Name" field={:name} col_style="width: 60%;">
            <%= pet.name %>
          </:col>
          <:action :let={pet} col_style="width: 40%;">
            <.link navigate={"/show/pet/#{pet.name}"}>
              Show Pet
            </.link>
          </:action>
        </Flop.Phoenix.table>
        """)

      assert [
               {"table", _,
                [
                  {"colgroup", _,
                   [
                     {"col", [{"style", "width: 60%;"}], _},
                     {"col", [{"style", "width: 40%;"}], _}
                   ]},
                  {"thead", _, _},
                  {"tbody", _, _}
                ]}
             ] = html
    end

    test "doesn't render colgroup on action col if no style attribute is set" do
      assigns = %{meta: %Flop.Meta{flop: %Flop{}}}

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table path="/pets" items={[%{}]} meta={@meta}>
          <:col></:col>
          <:action></:action>
        </Flop.Phoenix.table>
        """)

      assert [
               {"table", _,
                [
                  {"thead", _, _},
                  {"tbody", _, _}
                ]}
             ] = html
    end

    test "renders caption" do
      assert [
               {"table", [{"id", "some-table"}, {"class", "sortable-table"}],
                [
                  {"caption", [], ["some caption"]},
                  {"thead", _, _},
                  {"tbody", _, _}
                ]}
             ] = render_table(%{caption: "some caption"})
    end

    test "does not render table foot if option is not set" do
      html = render_table(%{})

      assert [
               {"table", [{"id", "some-table"}, {"class", "sortable-table"}],
                [{"thead", _, _}, {"tbody", _, _}]}
             ] = html
    end

    test "does not require path when passing event" do
      html = render_table(%{event: "sort-table", path: nil})

      assert [link] = Floki.find(html, "a:fl-contains('Name')")
      assert Floki.attribute(link, "phx-click") == ["sort-table"]
      assert Floki.attribute(link, "href") == ["#"]
    end

    test "raises if neither path nor event are passed" do
      assert_raise Flop.Phoenix.PathOrJSError,
                   fn ->
                     render_component(&table/1,
                       __changed__: nil,
                       col: fn _ -> nil end,
                       items: [%{name: "George"}],
                       meta: %Flop.Meta{flop: %Flop{}}
                     )
                   end
    end

    @tag capture_log: true
    test "does not crash if meta has errors" do
      {:error, meta} = Flop.validate(%{page: 0})
      render_table(%{meta: meta})
    end
  end

  describe "to_query/2" do
    test "does not add empty values" do
      refute %Flop{limit: nil} |> to_query() |> Keyword.has_key?(:limit)
      refute %Flop{order_by: []} |> to_query() |> Keyword.has_key?(:order_by)
      refute %Flop{filters: %{}} |> to_query() |> Keyword.has_key?(:filters)
    end

    test "does not add params for first page/offset" do
      refute %Flop{page: 1} |> to_query() |> Keyword.has_key?(:page)
      refute %Flop{offset: 0} |> to_query() |> Keyword.has_key?(:offset)
    end

    test "does not add limit/page_size if it matches default" do
      opts = [default_limit: 20]

      assert %Flop{page_size: 10}
             |> to_query(opts)
             |> Keyword.has_key?(:page_size)

      assert %Flop{limit: 10}
             |> to_query(opts)
             |> Keyword.has_key?(:limit)

      refute %Flop{page_size: 20}
             |> to_query(opts)
             |> Keyword.has_key?(:page_size)

      refute %Flop{limit: 20}
             |> to_query(opts)
             |> Keyword.has_key?(:limit)
    end

    test "does not order params if they match the default" do
      opts = [
        default_order: %{
          order_by: [:name, :age],
          order_directions: [:asc, :desc]
        }
      ]

      # order_by does not match default
      query =
        to_query(
          %Flop{order_by: [:name, :email], order_directions: [:asc, :desc]},
          opts
        )

      assert Keyword.has_key?(query, :order_by)
      assert Keyword.has_key?(query, :order_directions)

      # order_directions does not match default
      query =
        to_query(
          %Flop{order_by: [:name, :age], order_directions: [:desc, :desc]},
          opts
        )

      assert Keyword.has_key?(query, :order_by)
      assert Keyword.has_key?(query, :order_directions)

      # order_by and order_directions match default
      query =
        to_query(
          %Flop{order_by: [:name, :age], order_directions: [:asc, :desc]},
          opts
        )

      refute Keyword.has_key?(query, :order_by)
      refute Keyword.has_key?(query, :order_directions)
    end
  end

  describe "hidden_inputs_for_filter/1" do
    test "generates hidden fields from the given form" do
      form = %{Phoenix.Component.to_form(%{}, as: :form) | hidden: [id: 1]}

      html =
        (&Flop.Phoenix.hidden_inputs_for_filter/1)
        |> render_component(form: form)
        |> Floki.parse_fragment!()

      assert [input] = Floki.find(html, "input")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "id") == ["form_id"]
      assert Floki.attribute(input, "name") == ["form[id]"]
      assert Floki.attribute(input, "value") == ["1"]
    end

    test "generates hidden fields for lists from the given form" do
      form = %{
        Phoenix.Component.to_form(%{}, as: :a)
        | hidden: [field: ["a", "b", "c"]]
      }

      html =
        (&Flop.Phoenix.hidden_inputs_for_filter/1)
        |> render_component(form: form)
        |> Floki.parse_fragment!()

      assert [input_1, input_2, input_3] = Floki.find(html, "input")

      assert Floki.attribute(input_1, "type") == ["hidden"]
      assert Floki.attribute(input_1, "id") == ["a_field_0"]
      assert Floki.attribute(input_1, "name") == ["a[field][]"]
      assert Floki.attribute(input_1, "value") == ["a"]

      assert Floki.attribute(input_2, "type") == ["hidden"]
      assert Floki.attribute(input_2, "id") == ["a_field_1"]
      assert Floki.attribute(input_2, "name") == ["a[field][]"]
      assert Floki.attribute(input_2, "value") == ["b"]

      assert Floki.attribute(input_3, "type") == ["hidden"]
      assert Floki.attribute(input_3, "id") == ["a_field_2"]
      assert Floki.attribute(input_3, "name") == ["a[field][]"]
      assert Floki.attribute(input_3, "value") == ["c"]
    end
  end

  describe "filter_fields/1" do
    setup do
      meta = build(:meta_on_first_page)

      fields = [
        {:email, label: "E-mail"},
        {:phone, op: :ilike, type: "tel", class: "phone-input"},
        :field_without_opts
      ]

      %{fields: fields, meta: meta}
    end

    test "renders the hidden inputs", %{fields: fields, meta: meta} do
      html = render_form(%{fields: fields, meta: meta})

      assert [input] = Floki.find(html, "input[id='flop_page_size']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["10"]
    end

    test "renders the labels and filter inputs", %{
      fields: fields,
      meta: meta
    } do
      html = render_form(%{fields: fields, meta: meta})

      # labels
      assert [label] = Floki.find(html, "label[for='flop_filters_0_value']")
      assert String.trim(Floki.text(label)) == "E-mail"
      assert [_] = Floki.find(html, "label[for='flop_filters_1_value']")

      # field inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["email"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["phone"]

      # op input
      assert [input] = Floki.find(html, "input[id='flop_filters_1_op']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["ilike"]

      # value inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_value']")
      assert Floki.attribute(input, "type") == ["text"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_value']")
      assert Floki.attribute(input, "class") == ["phone-input"]
      assert Floki.attribute(input, "type") == ["tel"]
    end

    test "it overrides label when passed Phoenix.HTML.Safe" do
      assigns = %{
        meta: %Flop.Meta{flop: %Flop{}, schema: MyApp.Pet},
        items: [%{name: "George", age: 8}],
        opts: [],
        thead_label_component: fn assigns ->
          ~H"""
          <div data-test-id="thead-label-component">
            Custom
          </div>
          """
        end
      }

      html =
        parse_heex(~H"""
        <Flop.Phoenix.table items={@items} meta={@meta} on_sort={%JS{}} opts={@opts}>
          <:col :let={i} label={@thead_label_component.(%{})}>
            <%= i.name %>
          </:col>
        </Flop.Phoenix.table>
        """)

      assert [
               {"div", [{"data-test-id", "thead-label-component"}],
                ["\n  Custom\n"]}
             ] = Floki.find(html, ~s([data-test-id="thead-label-component"]))
    end

    test "renders multiple inputs for the same field", %{
      meta: meta
    } do
      filters = [
        %Flop.Filter{field: :age, op: :>=, value: "8"},
        %Flop.Filter{field: :email, op: :==, value: "some@email"},
        %Flop.Filter{field: :age, op: :<=, value: "14"}
      ]

      params = %{
        "filters" => [
          %{"field" => "age", "op" => ">=", "value" => "8"},
          %{"field" => "email", "op" => "==", "value" => "some@email"},
          %{"field" => "age", "op" => "<=", "value" => "14"}
        ]
      }

      meta = %{meta | flop: %{meta.flop | filters: filters}, params: params}

      fields = [
        {:age,
         label: "Minimum Age", op: :>=, type: "number", class: "number-input"},
        {:email, label: "E-mail", type: "email", class: "email-input"},
        {:age,
         label: "Maximum Age", op: :<=, type: "number", class: "number-input"}
      ]

      html = render_form(%{fields: fields, meta: meta})

      # labels
      assert [label] = Floki.find(html, "label[for='flop_filters_0_value']")
      assert String.trim(Floki.text(label)) == "Minimum Age"
      assert [label] = Floki.find(html, "label[for='flop_filters_1_value']")
      assert String.trim(Floki.text(label)) == "E-mail"
      assert [label] = Floki.find(html, "label[for='flop_filters_2_value']")
      assert String.trim(Floki.text(label)) == "Maximum Age"

      # field inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["age"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["email"]
      assert [input] = Floki.find(html, "input[id='flop_filters_2_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["age"]

      # op inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_op']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == [">="]
      assert [input] = Floki.find(html, "input[id='flop_filters_2_op']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["<="]

      # value inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_value']")
      assert Floki.attribute(input, "type") == ["number"]
      assert Floki.attribute(input, "value") == ["8"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_value']")
      assert Floki.attribute(input, "type") == ["email"]
      assert Floki.attribute(input, "value") == ["some@email"]
      assert [input] = Floki.find(html, "input[id='flop_filters_2_value']")
      assert Floki.attribute(input, "type") == ["number"]
      assert Floki.attribute(input, "value") == ["14"]
    end

    test "renders multiple inputs for the same field with omitted opts", %{
      meta: meta
    } do
      filters = [
        %Flop.Filter{field: :email, op: :==, value: "first@email"},
        %Flop.Filter{field: :age, op: :>=, value: "8"},
        %Flop.Filter{field: :email, op: :!=, value: "second@email"}
      ]

      params = %{
        "filters" => [
          %{"field" => "email", "value" => "first@email"},
          %{"field" => "age", "op" => ">=", "value" => "8"},
          %{"field" => "email", "op" => "!=", "value" => "second@email"}
        ]
      }

      meta = %{meta | flop: %{meta.flop | filters: filters}, params: params}

      fields = [
        :email,
        {:age,
         label: "Minimum Age", op: :>=, type: "number", class: "number-input"},
        {:email,
         label: "Second E-mail", op: :!=, type: "email", class: "email-input"}
      ]

      html = render_form(%{fields: fields, meta: meta})

      # labels
      assert [label] = Floki.find(html, "label[for='flop_filters_0_value']")
      assert String.trim(Floki.text(label)) == "Email"
      assert [label] = Floki.find(html, "label[for='flop_filters_1_value']")
      assert String.trim(Floki.text(label)) == "Minimum Age"
      assert [label] = Floki.find(html, "label[for='flop_filters_2_value']")
      assert String.trim(Floki.text(label)) == "Second E-mail"

      # field inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["email"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["age"]
      assert [input] = Floki.find(html, "input[id='flop_filters_2_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["email"]

      # value inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_value']")
      assert Floki.attribute(input, "type") == ["text"]
      assert Floki.attribute(input, "value") == ["first@email"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_value']")
      assert Floki.attribute(input, "type") == ["number"]
      assert Floki.attribute(input, "value") == ["8"]
      assert [input] = Floki.find(html, "input[id='flop_filters_2_value']")
      assert Floki.attribute(input, "type") == ["email"]
      assert Floki.attribute(input, "value") == ["second@email"]
    end

    @tag capture_log: true
    test "renders the labels and filter inputs with errors", %{
      fields: fields
    } do
      invalid_params = %{
        "filters" => [
          %{"field" => "email", "value" => ""},
          %{"field" => "phone", "op" => "ilike", "value" => "123"}
        ],
        "page" => "0"
      }

      {:error, meta} = Flop.validate(invalid_params)

      html = render_form(%{fields: fields, meta: meta})

      # labels
      assert [label] = Floki.find(html, "label[for='flop_filters_0_value']")
      assert String.trim(Floki.text(label)) == "E-mail"
      assert [_] = Floki.find(html, "label[for='flop_filters_1_value']")

      # field inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["email"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["phone"]

      # op input
      assert [input] = Floki.find(html, "input[id='flop_filters_1_op']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["ilike"]

      # value inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_value']")
      assert Floki.attribute(input, "type") == ["text"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_value']")
      assert Floki.attribute(input, "type") == ["tel"]
    end

    test "optionally only renders existing filters", %{
      fields: fields,
      meta: meta
    } do
      meta = %{meta | flop: %Flop{filters: [%Filter{field: :phone}]}}
      html = render_form(%{dynamic: true, fields: fields, meta: meta})

      assert [label] = Floki.find(html, "label[for='flop_filters_0_value']")
      assert String.trim(Floki.text(label)) == "Phone"

      assert [] = Floki.find(html, "label[for='flop_filters_1_value']")
    end

    test "matches dynamic filters and field config correctly", %{meta: meta} do
      meta = %{
        meta
        | flop: %Flop{
            filters: [
              %Filter{field: :age, op: :>=, value: "8"},
              %Filter{field: :name, value: "George"},
              %Filter{field: :email, value: "geo"}
            ]
          }
      }

      fields = [
        {:email, label: "E-mail", type: "email", class: "email-input"},
        {:age, label: "Age", type: "number", class: "number-input"},
        :name
      ]

      html = render_form(%{dynamic: true, fields: fields, meta: meta})

      # labels
      assert [label] = Floki.find(html, "label[for='flop_filters_0_value']")
      assert String.trim(Floki.text(label)) == "Age"
      assert [label] = Floki.find(html, "label[for='flop_filters_1_value']")
      assert String.trim(Floki.text(label)) == "Name"
      assert [label] = Floki.find(html, "label[for='flop_filters_2_value']")
      assert String.trim(Floki.text(label)) == "E-mail"

      # field inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["age"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["name"]
      assert [input] = Floki.find(html, "input[id='flop_filters_2_field']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == ["email"]

      # op input
      assert [input] = Floki.find(html, "input[id='flop_filters_0_op']")
      assert Floki.attribute(input, "type") == ["hidden"]
      assert Floki.attribute(input, "value") == [">="]

      # value inputs
      assert [input] = Floki.find(html, "input[id='flop_filters_0_value']")
      assert Floki.attribute(input, "class") == ["number-input"]
      assert Floki.attribute(input, "type") == ["number"]
      assert Floki.attribute(input, "value") == ["8"]
      assert [input] = Floki.find(html, "input[id='flop_filters_1_value']")
      assert Floki.attribute(input, "type") == ["text"]
      assert Floki.attribute(input, "value") == ["George"]
      assert [input] = Floki.find(html, "input[id='flop_filters_2_value']")
      assert Floki.attribute(input, "class") == ["email-input"]
      assert Floki.attribute(input, "type") == ["email"]
      assert Floki.attribute(input, "value") == ["geo"]
    end

    test "renders filters when given a offset", %{
      fields: fields,
      meta: meta
    } do
      html =
        meta
        |> Form.form_for("/", fn f ->
          inputs_for(f, :filters, [fields: fields, offset: 5], fn fo ->
            render_component(&hidden_inputs_for_filter/1, form: fo)
          end)
        end)
        |> safe_to_string()
        |> Floki.parse_fragment!()

      # hidden fields
      assert [_] = Floki.find(html, "input[id='flop_filters_5_field']")
      assert [_] = Floki.find(html, "input[id='flop_filters_6_field']")
      assert [_] = Floki.find(html, "input[id='flop_filters_7_field']")

      # op input
      assert [_] = Floki.find(html, "input[id='flop_filters_6_op']")
    end

    test "raises error if the form is not a form for meta" do
      assert_raise Flop.Phoenix.NoMetaFormError, fn ->
        render_component(&filter_fields/1, form: to_form(%{}))
      end
    end

    test "raises error if fields are invalid" do
      assigns = %{
        form: to_form(%Flop.Meta{}),
        fields: ["name"]
      }

      assert_raise Flop.Phoenix.InvalidFilterFieldConfigError, fn ->
        rendered_to_string(~H"""
        <Flop.Phoenix.filter_fields fields={@fields} form={@form}>
        </Flop.Phoenix.filter_fields>
        """)
      end
    end
  end

  defmodule TestBackend do
    use Flop, default_limit: 41, repo: MyApp.Repo
  end

  describe "build_path/3" do
    test "gets the backend option from the meta struct to retrieve defaults" do
      meta = %Flop.Meta{backend: TestBackend, flop: %Flop{page_size: 40}}
      assert build_path("/pets", meta) == "/pets?page_size=40"

      meta = %Flop.Meta{backend: TestBackend, flop: %Flop{page_size: 41}}
      assert build_path("/pets", meta) == "/pets"
    end

    test "gets the for option from the meta struct to retrieve defaults" do
      meta = %Flop.Meta{schema: Pet, flop: %Flop{page_size: 21}}
      assert build_path("/pets", meta) == "/pets?page_size=21"

      meta = %Flop.Meta{schema: Pet, flop: %Flop{page_size: 20}}
      assert build_path("/pets", meta) == "/pets"
    end
  end

  defmodule TestSchema do
    use Ecto.Schema

    @derive {Flop.Schema, filterable: [:email, :age], sortable: []}

    schema "test_schema" do
      field(:age, :integer)
      field(:email, :string)
    end
  end
end
