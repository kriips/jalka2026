defmodule Jalka2026.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Jalka2026.Accounts

  @derive {Inspect, except: [:password]}
  schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:password, :string, virtual: true)
    field(:hashed_password, :string)
    field(:confirmed_at, :naive_datetime)
    field(:is_admin, :boolean, default: false)
    field(:competition_id, :string, default: "wc-2026")
    field(:theme, :string, default: "light")

    timestamps()
  end

  @doc """
  Checks if a user is an admin.
  """
  def admin?(%__MODULE__{is_admin: is_admin}), do: is_admin == true
  def admin?(_), do: false

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    competition_id = Jalka2026.Competitions.current_id()

    user
    |> cast(attrs, [:name, :password, :email])
    |> put_change(:competition_id, competition_id)
    |> validate_name()
    |> validate_password(opts)
    |> validate_optional_email()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :password, :group_score, :playoff_score])
    |> unique_constraint([:name, :competition_id])
    |> validate_required([:name, :password])
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required([:name])
    |> unsafe_validate_unique([:name, :competition_id], Jalka2026.Repo)
    |> unique_constraint([:name, :competition_id])
    |> check_whitelist
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Jalka2026.Repo)
    |> unique_constraint(:email)
  end

  defp validate_optional_email(changeset) do
    case get_change(changeset, :email) do
      nil ->
        changeset

      "" ->
        changeset

      _email ->
        changeset
        |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
          message: "peab sisaldama @ märki ja mitte tühikuid"
        )
        |> validate_length(:email, max: 160)
        |> unsafe_validate_unique(:email, Jalka2026.Repo)
        |> unique_constraint(:email)
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 5, max: 80)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp check_whitelist(changeset) do
    competition_id = Jalka2026.Competitions.current_id()

    case Accounts.get_allowed_users_exactly_by_name(get_field(changeset, :name), competition_id) do
      [] -> add_error(changeset, :name, "ei kuulu nimekirja")
      _ -> changeset
    end
  end

  @doc """
  A user changeset for changing the theme preference.
  """
  def theme_changeset(user, attrs) do
    user
    |> cast(attrs, [:theme])
    |> validate_inclusion(:theme, ["light", "dark"])
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Jalka2026.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
