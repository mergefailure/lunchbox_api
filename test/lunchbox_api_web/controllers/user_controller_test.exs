defmodule LunchboxApiWeb.UserControllerTest do
  use LunchboxApiWeb.ConnCase

  alias LunchboxApi.Accounts
  alias LunchboxApi.Accounts.User
  alias Plug.Test

  @create_attrs %{
    email: "some_email@mail.com",
    password: "some_password_098765",
    password_confirmation: "some_password_098765"
  }
  @update_attrs %{
    email: "some_updated_email@mymail.com",
    password: "some_password_zyxwv",
    password_confirmation: "some_password_zyxwv"
  }
  @invalid_attrs %{email: nil, password: nil, password_confirmation: nil}
  @current_user_attrs %{
    email: "someCurrentUser@email.com",
    password: "some_password_67890",
    password_confirmation: "some_password_67890"
  }

  def fixture(:user) do
    {:ok, user} = Accounts.create_user(@create_attrs)
    user
  end

  def fixture(:current_user) do
    {:ok, current_user} = Accounts.create_user(@current_user_attrs)
    current_user
  end

  setup %{conn: conn} do
    {:ok, conn: conn, current_user: current_user} = setup_current_user(conn)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), current_user: current_user}
  end

  describe "index" do
    test "lists all users", %{conn: conn, current_user: current_user} do
      conn = get(conn, Routes.user_path(conn, :index))

      assert json_response(conn, 200)["data"] == [
               %{
                 "id" => current_user.id,
                 "email" => current_user.email
               }
             ]
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))

      hashed_password = Argon2.add_hash(@create_attrs.password)

      assert %{
               "id" => id,
               "email" => "some_email@mail.com"
             } = json_response(conn, 200)["data"]

      refute Map.get(json_response(conn, 200)["data"], :password)
    end

    test "does not create a user when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
      assert %{"email" => _email, "password" => _password} = json_response(conn, 422)["errors"]
      refute json_response(conn, 422)["meta"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn = put(conn, Routes.user_path(conn, :update, user), user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "id" => id,
               "email" => "some_updated_email@mymail.com"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, Routes.user_path(conn, :update, user), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, Routes.user_path(conn, :delete, user))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.user_path(conn, :show, user))
      end
    end
  end

  describe "sign_in user" do
    test "renders user when user credentials are good", %{conn: conn, current_user: current_user} do
      conn =
        post(
          conn,
          Routes.user_path(conn, :sign_in, %{
            email: current_user.email,
            password: @current_user_attrs.password
          })
        )

      assert json_response(conn, 200)["data"] == %{
               "user" => %{"id" => current_user.id, "email" => current_user.email}
             }
    end

    test "renders errors when user credentials are bad", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.user_path(conn, :sign_in, %{email: "nonexistent@mail.com", password: "rubbish"})
        )

      assert json_response(conn, 401)["errors"] == %{"detail" => "Wrong email or password"}
    end
  end

  defp create_user(_) do
    user = fixture(:user)
    {:ok, user: user}
  end

  defp setup_current_user(conn) do
    current_user = fixture(:current_user)

    {:ok,
     conn: Test.init_test_session(conn, current_user_id: current_user.id),
     current_user: current_user}
  end
end
